/*! coi-serviceworker v0.1.7 - Guido Zuidhof, licensed under MIT */
let coepCredentialless = false;
if (typeof window === 'undefined') {
    self.addEventListener("install", () => self.skipWaiting());
    self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));

    self.addEventListener("message", (ev) => {
        if (!ev.data) {
            return;
        } else if (ev.data.type === "deregister") {
            self.registration
                .unregister()
                .then(() => {
                    return self.clients.matchAll();
                })
                .then(clients => {
                    clients.forEach((client) => client.navigate(client.url));
                });
        } else if (ev.data.type === "coepCredentialless") {
            coepCredentialless = ev.data.value;
        }
    });

    self.addEventListener("fetch", function (event) {
        const request = event.request;
        if (request.cache === "only-if-cached" && request.mode !== "same-origin") {
            return;
        }

        const coep = coepCredentialless ? "credentialless" : "require-corp";

        event.respondWith(
            fetch(request)
                .then((response) => {
                    if (response.status === 0) {
                        return response;
                    }

                    const newHeaders = new Headers(response.headers);
                    newHeaders.set("Cross-Origin-Opener-Policy", "same-origin");
                    newHeaders.set("Cross-Origin-Embedder-Policy", coep);
                    newHeaders.set("Cross-Origin-Resource-Policy", "cross-origin");

                    return new Response(response.body, {
                        status: response.status,
                        statusText: response.statusText,
                        headers: newHeaders,
                    });
                })
                .catch((e) => console.error(e))
        );
    });
} else {
    (() => {
        const reloadedBySelf = window.sessionStorage.getItem("coiReloadedBySelf");
        window.sessionStorage.removeItem("coiReloadedBySelf");
        const coepDegradation = (reloadedBySelf == "coepdegrade");

        // You can customize the behavior by checking attributes on the script tag:
        // <script src="coi-serviceworker.js" coep-credentialless="true"></script>
        const currentScript = document.currentScript;
        const coepCredentialless = currentScript && currentScript.attributes.getNamedItem("coep-credentialless") !== null;

        if (window.crossOriginIsolated || coepDegradation) {
            return;
        }

        if (!window.isSecureContext) {
            console.log("COOP/COEP Service Worker not registered: context is not secure.");
            return;
        }

        if ("serviceWorker" in navigator) {
            navigator.serviceWorker.register(window.document.currentScript.src).then(
                (registration) => {
                    registration.addEventListener("updatefound", () => {
                        window.sessionStorage.setItem("coiReloadedBySelf", "true");
                        window.location.reload();
                    });

                    // If the registration is active, but it's not controlling the page
                    if (registration.active && !navigator.serviceWorker.controller) {
                        window.sessionStorage.setItem("coiReloadedBySelf", "true");
                        window.location.reload();
                    }
                },
                (err) => {
                    console.error("COOP/COEP Service Worker failed to register:", err);
                }
            );
        }
    })();
}
