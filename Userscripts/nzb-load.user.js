// ==UserScript==
// @name                nzb-load
// @description         Finds NZBs from NZBlnk links and sends them to SABnzbd.
// @description:de_DE   Sucht NZBs zu NZBlnk-Links und übergibt sie an SABnzbd.
// @author              LordBex
// @version             v2.3.7
// @match               *://*/*
// @inject-into         content
// @grant               GM_xmlhttpRequest
// @grant               GM.xmlhttpRequest
// @grant               GM.setValue
// @grant               GM.getValue
// @grant               GM.registerMenuCommand
// @connect             nzbindex.com
// @connect             www.nzbking.com
// @connect             binsearch.info
// @connect             www.binsearch.info
// @connect             treasure-maps.com
// @connect             file.treasure-maps.com
// @connect             newzbay.cc
// @connect             ninjacentral.co.za
// @connect             drunkenslug.com
// @connect             nzbfinder.ws
// @connect             videothek.io
// @connect             localhost
// @connect             *
// @icon                https://i.imgur.com/O1ao7fL.png
// ==/UserScript==

// ------------------------------------------------------------
//- Default Config:

console.log("nzb-load loaded")

// Default settings
const DEFAULT_SETTINGS = {
    ausgabe: 'sab_menu',
    treasure_maps_api_key: '',
    newzbay_api_key: '',
    ninjacentral_api_key: '',
    drunkenslug_api_key: '',
    nzbfinder_api_key: '',
    videothek_api_key: '',

    sab_api_key: '',
    sab_url: 'http://localhost:8080/api',
    sab_categories: [],
    sab_hidden_categories: [],
    sab_default_category: '*',
    sab_sub_menu: true,

};

// Initialisierung der Einstellungen
const SETTINGS = { ...DEFAULT_SETTINGS, sab_categories: [], sab_hidden_categories: [] };
const SETTINGS_KEY = 'nzb-load-settings';

function supportedSettings(input) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) {
        throw new Error('Die Einstellungsdatei hat ein ungültiges Format.');
    }
    const result = Object.fromEntries(Object.keys(DEFAULT_SETTINGS)
        .filter(key => Object.prototype.hasOwnProperty.call(input, key))
        .map(key => [key, input[key]]));
    if ('ausgabe' in result && !['sab_menu', 'sabnzbd', 'download'].includes(result.ausgabe)) {
        result.ausgabe = 'sab_menu';
    }
    return result;
}

// Load settings before opening dialogs or processing links.
async function loadSettings() {
    try {
        const savedSettings = await GM.getValue(SETTINGS_KEY);
        if (savedSettings && typeof savedSettings === 'object') {
            Object.assign(SETTINGS, supportedSettings(savedSettings));
        }
        SETTINGS.sab_categories = (Array.isArray(SETTINGS.sab_categories)
            ? SETTINGS.sab_categories : []).map(item =>
                typeof item === 'string' ? { value: item, fav: false } : item
            );
        SETTINGS.sab_hidden_categories = Array.isArray(SETTINGS.sab_hidden_categories)
            ? SETTINGS.sab_hidden_categories.filter(name => typeof name === 'string') : [];
        document.dispatchEvent(new CustomEvent('init-nzb-load', {
            detail: { version: GM.info.script.version, name: GM.info.script.name }
        }));
        return true;
    } catch {
        console.error('nzb-load: Einstellungen konnten nicht geladen werden.');
        return false;
    }
}

const settingsReady = loadSettings();

async function saveSettings(settings) {
    if (!await settingsReady) {
        throw new Error('Einstellungen konnten nicht geladen werden. Bitte die Seite neu laden.');
    }
    const snapshot = JSON.parse(JSON.stringify({ ...SETTINGS, ...settings }));
    await GM.setValue(SETTINGS_KEY, snapshot);
    const saved = await GM.getValue(SETTINGS_KEY);
    if (!saved || Object.keys(snapshot).some(key =>
        JSON.stringify(saved[key]) !== JSON.stringify(snapshot[key]))) {
        throw new Error('Die Einstellungen wurden nicht dauerhaft gespeichert.');
    }
    Object.assign(SETTINGS, snapshot);
}

// Keep locally hidden categories out of every refreshed server list.
function refreshSabCategories(categories) {
    const hidden = new Set(SETTINGS.sab_hidden_categories.map(name => name.toLowerCase()));
    const favorites = new Set(SETTINGS.sab_categories
        .filter(category => category && category.fav)
        .map(category => category.value.toLowerCase()));
    SETTINGS.sab_categories = categories.map(String)
        .filter(name => !hidden.has(name.toLowerCase()))
        .map(value => ({ value, fav: favorites.has(value.toLowerCase()) }));
    return SETTINGS.sab_categories;
}

// ------------------------------------------------------------
// menu buttons

function getDownloadButton(parameters) {
    return {
        name: 'NZB-Datei speichern',
        f: () => downloadAndSave(parameters),
        bgColor: '#0D4715',
        icon: 'https://raw.githubusercontent.com/sabnzbd/sabnzbd/refs/heads/develop/icons/nzb.ico'
    }
}

async function openMenu(buttons) {
    infoModal.closeModal()
    modal.showModal(buttons)
}

function customHandler({downloadLink, fileName, password}) {
    // wird ausgeführt, wenn AUSGABE auf 'custom' gesetzt ist
    alert("Custom Handler") // Hier kann eigener Code eingefügt werden
}

// ------------------------------------------------------------
// sab-code

const SABNZBD = {
    addUrl: function ({downloadLink, fileName, password, category = '*', onFailure}) {
        // A string body avoids passing FormData through the extension message bridge.
        const body = new URLSearchParams();
        body.set('name', downloadLink);
        body.set('mode', 'addurl');
        body.set('output', 'json');
        body.set('apikey', SETTINGS.sab_api_key.trim());
        body.set('cat', category);
        if (fileName) body.set('nzbname', fileName);
        if (password) body.set('password', password);

        SABNZBD.post(body.toString(), 'application/x-www-form-urlencoded; charset=UTF-8', onFailure);
    },

    post: function (body, contentType, onFailure) {
        modal.closeModal();
        infoModal.closeModal();

        const fail = message => {
            infoModal.resetModal();
            const text = document.createElement('p');
            text.style.color = 'red';
            text.textContent = message;
            infoModal.modalContent.appendChild(text);
            if (onFailure) onFailure();
            infoModal.showModal();
        };
        try {
            GM_xmlhttpRequest({
                method: 'POST',
                url: SETTINGS.sab_url.trim(),
                data: body,
                headers: {
                    'Content-Type': contentType,
                    'Accept': 'application/json'
                },
                timeout: 20000,
                onload: function (response) {
                    if (response.status !== 200) {
                        fail('SABnzbd antwortet mit HTTP ' + response.status + '.');
                        return;
                    }
                    let result;
                    try { result = JSON.parse(response.responseText); }
                    catch {
                        fail('SABnzbd hat keine gültige JSON-Antwort geliefert.');
                        return;
                    }
                    if (!result || result.status !== true) {
                        fail('SABnzbd hat den Auftrag abgelehnt: ' +
                            (result && result.error || 'Unbekannter Fehler'));
                    }
                },
                onerror: function (response) {
                    const status = Number(response && response.status) || 0;
                    fail('Die Sendeanfrage an SABnzbd ist fehlgeschlagen (HTTP ' + status + ').');
                },
                ontimeout: function () {
                    fail('Keine rechtzeitige Antwort von SABnzbd. Bitte vor erneutem Senden die Warteschlange prüfen.');
                }
            });
        } catch {
            fail('Userscripts konnte die Sendeanfrage nicht starten.');
        }
    },

    uploadNzb: function ({responseText, fileName, password, category = SETTINGS.sab_default_category, onFailure}) {
        // Keep the multipart body as a string for the mobile extension bridge.
        const nonce = Array.from(crypto.getRandomValues(new Uint8Array(16)), byte =>
            byte.toString(16).padStart(2, '0')).join('');
        const boundary = 'nzb-load-' + nonce;
        const name = (fileName || 'download').replace(/[\\/"\x00-\x1F\x7F]/g, '_');
        const filename = /\.nzb$/i.test(name) ? name : name + '.nzb';
        const fields = { mode: 'addfile', output: 'json', cat: category, apikey: SETTINGS.sab_api_key.trim() };
        if (fileName) fields.nzbname = fileName;
        if (password) fields.password = password;
        const fieldParts = Object.entries(fields).map(([key, value]) =>
            `--${boundary}\r\nContent-Disposition: form-data; name="${key}"\r\n\r\n${value}\r\n`);
        const filePart = `--${boundary}\r\nContent-Disposition: form-data; name="name"; filename="${filename}"\r\n` +
            `Content-Type: application/x-nzb\r\n\r\n${responseText}\r\n--${boundary}--\r\n`;
        SABNZBD.post(fieldParts.join('') + filePart, 'multipart/form-data; boundary=' + boundary, onFailure);
    },

    send: async function ({downloadLink, fetchNZB, fileName, password, category}) {
        const parameters = {downloadLink, fetchNZB, fileName, password};
        const onFailure = () => offerNZBSave(parameters);
        if (!fetchNZB) {
            SABNZBD.addUrl({downloadLink, fileName, password, category, onFailure});
            return;
        }
        modal.closeModal();
        infoModal.resetModal();
        infoModal.print('Lade NZB-Datei vom Suchdienst …');
        infoModal.showModal();
        try {
            const responseText = await fetchNZB();
            SABNZBD.uploadNzb({responseText, fileName, password, category, onFailure});
        } catch (error) {
            const message = document.createElement('p');
            message.textContent = error instanceof IndexerRequestError
                ? error.message : 'Die NZB-Datei konnte nicht geladen oder an SABnzbd übergeben werden.';
            infoModal.modalContent.appendChild(message);
            onFailure();
        }
    },

    getCategories: function ({callback, failed_callback, url, key}) {
        url = (url || SETTINGS.sab_url || '').trim();
        key = (key || SETTINGS.sab_api_key || '').trim();
        const fail = message => {
            if (failed_callback) failed_callback(new Error(message));
            else alert(message);
        };
        if (!url || !key) {
            fail('Bitte gib zuerst die SABnzbd URL und den API-Key ein.');
            return;
        }
        let requestURL;
        try {
            requestURL = new URL(url);
            if (!['http:', 'https:'].includes(requestURL.protocol)) throw new Error();
            requestURL.searchParams.set('output', 'json');
            requestURL.searchParams.set('mode', 'get_cats');
            requestURL.searchParams.set('apikey', key);
        } catch {
            fail('Die SABnzbd URL ist ungültig.');
            return;
        }
        GM_xmlhttpRequest({
            method: 'GET',
            url: requestURL.toString(),
            headers: { 'Accept': 'application/json' },
            onload: response => {
                if (response.status !== 200) {
                    fail('SABnzbd antwortet mit HTTP ' + response.status + '.');
                    return;
                }
                let data;
                try { data = JSON.parse(response.responseText); }
                catch {
                    fail('SABnzbd hat keine gültige JSON-Antwort geliefert.');
                    return;
                }
                if (!Array.isArray(data.categories) || !data.categories.length) {
                    fail('Keine Kategorien erhalten. Bitte SABnzbd URL und API-Key prüfen.');
                    return;
                }
                if (callback) callback(data.categories);
            },
            onerror: () => fail('SABnzbd ist nicht erreichbar. Bitte Adresse und Safari-Berechtigungen prüfen.'),
            ontimeout: () => fail('Die Anfrage an SABnzbd hat zu lange gedauert.'),
            timeout: 15000
        });
    },

    makeButton: function (parameters, category) {
        if (typeof category === 'string') { // migration to new config format
            category = {
                value: category,
                fav: false
            }
        }

        let name = category.value.charAt(0).toUpperCase() + category.value.slice(1)

        if (category.fav) {
            name = '⭐ ' + name
        }

        return {
            name: name,
            value: category.value.toLowerCase(),
            f: () => {
                SABNZBD.send({ ...parameters, category: category.value });
            }
        };
    }
}

function getCategoriesButtons(parameters, sort_callback) {
    if (SETTINGS.sab_categories.length > 0) {
        let cats = SETTINGS.sab_categories;

        if (sort_callback) {
            cats = cats.sort(sort_callback);
        }

        return cats.map(item => {
            return SABNZBD.makeButton(parameters, item);
        })
    } else {
        console.warn("No categories found in settings.")
        alert("Keine Kategorien in den Einstellungen gefunden. Bitte zuerst Kategorien hinzufügen.")
    }
}

// ------------------------------------------------------------
// download file-code

function saveFile({responseText, fileName, fileType = "application/x-nzb", fileExtension = '.nzb'}) {
    let blob = new Blob([responseText], {type: fileType});
    let link = document.createElement('a');
    link.href = URL.createObjectURL(blob);

    if (!fileName) {
        fileName = 'file' + fileExtension;
    } else if (!fileName.endsWith(fileExtension)) {
        fileName = fileName + fileExtension
    }

    link.download = fileName // Dateiname ändern
    link.style.display = 'none';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

function extractFileNameFromResponse(url, response) {
    if (response.responseHeaders) {
        const contentDisposition = response.responseHeaders
            .split('\n')
            .find(header => header.toLowerCase().startsWith('content-disposition:'));

        if (contentDisposition) {
            console.log("Content-Disposition Header vom Download:", contentDisposition)
            const filenameMatch = contentDisposition.match(/filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/);
            if (filenameMatch && filenameMatch[1]) {
                return filenameMatch[1].replace(/['"]/g, '');
            }
        }
    }
    // Fallback: Extrahiere den Dateinamen aus der URL
    const urlParts = url.split('/');
    const lastPart = urlParts[urlParts.length - 1];
    const fileName = lastPart.split('?')[0]; // Entferne Query-Parameter
    console.log("Dateiname aus URL extrahiert:", fileName)
    return fileName || 'download.nzb'; // Fallback-Dateiname
}

function offerNZBSave(parameters) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'btn';
    button.textContent = 'NZB-Datei speichern';
    button.onclick = () => downloadAndSave(parameters);
    infoModal.modalContent.appendChild(button);
}

async function downloadFile({downloadLink, fetchNZB, fileName, password, callback}) {
    const responseText = fetchNZB
        ? await fetchNZB()
        : await indexerRequest(new URL(downloadLink), 'application/x-nzb, application/xml, text/xml');
    const root = indexerXML(responseText, 16 * 1024 * 1024);
    if (root.localName !== 'nzb' || !root.getElementsByTagNameNS('*', 'file').length) {
        throw new Error('Der Suchdienst hat keine gültige NZB-Datei geliefert.');
    }
    const result = {responseText, fileName: fileName || 'download', password};
    if (callback) callback(result);
    return result;
}

async function downloadAndSave(parameters) {
    modal.closeModal();
    infoModal.resetModal();
    infoModal.print('Lade NZB-Datei zum Speichern …');
    infoModal.showModal();
    try {
        const result = await downloadFile(parameters);
        const name = result.fileName.replace(/\.nzb$/i, '');
        result.fileName = (result.password ? `${name}{{${result.password}}}` : name)
            .replace(/[\\/"\x00-\x1F\x7F]/g, '_') + '.nzb';
        saveFile(result);
        infoModal.resetModal();
        infoModal.print('NZB-Datei zum Speichern bereitgestellt.');
    } catch (error) {
        const message = document.createElement('p');
        message.textContent = error instanceof Error ? error.message : 'Die NZB-Datei konnte nicht geladen werden.';
        infoModal.modalContent.appendChild(message);
        offerNZBSave(parameters);
    }
}

// ------------------------------------------------------------
// handle menu

customElements.define('menu-select-modal', class MenuSelectModal extends HTMLElement {
    constructor() {
        super();
    }

    connectedCallback() {
        // Create a shadow root
        const shadow = this.attachShadow({mode: "open"});
        shadow.innerHTML = `
             <style>
                .btn {
                    --_bg-color: var(--bg-color, #06f);
                    align-items: center;
                    background-color: var(--_bg-color);
                    border: 2px solid var(--_bg-color);
                    box-sizing: border-box;
                    color: #fff;
                    cursor: pointer;
                    display: inline-flex;
                    fill: #000;
                    font-size: 24px;
                    font-weight: 400;
                    height: 48px;
                    justify-content: center;
                    line-height: 24px;
                    width: 100%;
                    outline: 0;
                    padding: 0 17px;
                    text-align: center;
                    text-decoration: none;
                    transition: all .3s;
                    user-select: none;
                    -webkit-user-select: none;
                    touch-action: manipulation;
                    border-radius: 5px;
                    gap: 5px;
                }

                .btn:hover {
                    filter: brightness(70%);
                }

                dialog {
                    border: none !important;
                    border-radius: calc(5px * 3.74);
                    box-shadow: 0 0 #0000, 0 0 #0000, 0 25px 50px -12px rgba(0, 0, 0, 0.25);
                    background-color: rgb(33, 37, 41);
                    padding: 1.6rem;
                    max-height: 70%;
                    max-width: max(400px, 100vw);
                }

                .dialog-header {
                    color: white;
                    font-family: Inter, sans-serif;
                    font-size: 22px;
                    font-weight: 600;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding-bottom: 15px;
                    margin-bottom: 15px;
                    border-bottom: 1px solid #444;
                }

                .buttons {
                    display: flex;
                    flex-direction: column;
                    gap: 15px;
                    min-width: 400px;
                    margin-top: 5px;
                }

                .close {
                    all: initial;
                    background: unset;
                    padding: 5px;
                    margin: 0;
                    border: unset;
                }

                .close {
                    all: initial;
                    background: unset;
                    padding: 8px;
                    margin: 0;
                    border: unset;
                    border-radius: 50%;
                    cursor: pointer;
                    transition: background-color 0.2s, transform 0.1s;
                }

                .close:hover {
                    background-color: rgba(255, 255, 255, 0.1);
                    transform: scale(1.1);
                }

                .close:active {
                    transform: scale(0.95);
                }

                .close:not(:hover) svg {
                    opacity: 0.6;
                }

                @media screen and (max-width: 450px) {
                    .buttons {
                        display: flex;
                        flex-direction: column;
                        gap: 10px;
                        min-width: 300px;
                    }
                }

                @media screen and (max-width: 350px) {
                    .buttons {
                        display: flex;
                        flex-direction: column;
                        gap: 10px;
                        min-width: 150px;
                    }
                }


            </style>

            <div data-bs-theme="dark">
                 <dialog id="dialog-1">
                    <form method="dialog">
                        <div class="dialog-header">
                            <span>Wähle ...</span>
                            <button class="close">
                                <svg xmlns='http://www.w3.org/2000/svg' width="16" height="16" viewBox='0 0 16 16' fill='#CCC'>
                                    <path d='M.293.293a1 1 0 0 1 1.414 0L8 6.586 14.293.293a1 1 0 1 1 1.414 1.414L9.414 8l6.293 6.293a1 1 0 0 1-1.414 1.414L8 9.414l-6.293 6.293a1 1 0 0 1-1.414-1.414L6.586 8 .293 1.707a1 1 0 0 1 0-1.414z'/>
                                </svg>
                            </button>
                        </div>

                        <div class="buttons buttons-here">
                            <p>...</p>
                        </div>
                    </form>
                </dialog>
            </div>
        `

        this.dialog = shadow.querySelector('dialog')
    }

    showModal(items) {
        this.dialog.showModal()

        const modalContent = this.shadowRoot.querySelector('.buttons-here');
        modalContent.innerHTML = '';

        items.forEach(item => {
            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'btn';

            if (item.innerHTML) {
                button.innerHTML = item.innerHTML;
            }

            if (item.icon) {
                const img = document.createElement('img');
                img.src = item.icon;
                img.style.marginRight = '8px';
                img.style.width = '24px';
                img.style.height = '24px';
                button.appendChild(img);
            }

            button.appendChild(document.createTextNode(item.name));

            if (item.bgColor) {
                button.style.setProperty('--bg-color', item.bgColor);
            }

            button.onclick = () => {
                item.f(); // call function
            };
            modalContent.appendChild(button);
        });
    }

    closeModal() {
        this.dialog.close()
    }
});

const modal = document.createElement('menu-select-modal');
document.body.appendChild(modal);

// ------------------------------------------------------------
// info dialog handler

customElements.define('nzblnk-info-modal', class NzbInfoModal extends HTMLElement {
    constructor() {
        super();
        this.createModal()
        this.closeTimer = null
    }

    createModal() {
        // Create a shadow root
        const shadow = this.attachShadow({mode: "open"});
        // language=HTML
        shadow.innerHTML = `
            <style>

                .btn {
                    align-items: center;
                    background-color: #06f;
                    border: 2px solid #06f;
                    box-sizing: border-box;
                    color: #fff;
                    cursor: pointer;
                    display: inline-flex;
                    fill: #000;
                    font-size: 24px;
                    font-weight: 400;
                    height: 48px;
                    justify-content: center;
                    line-height: 24px;
                    width: 100%;
                    outline: 0;
                    padding: 0 17px;
                    text-align: center;
                    text-decoration: none;
                    transition: all .3s;
                    user-select: none;
                    -webkit-user-select: none;
                    touch-action: manipulation;
                    border-radius: 5px;
                }

                .btn:hover {
                    background-color: #3385ff;
                    border-color: #3385ff;
                    fill: #06f;
                }

                dialog {
                    border: none !important;
                    border-radius: calc(5px * 3.74);
                    box-shadow: 0 0 #0000, 0 0 #0000, 0 25px 50px -12px rgba(0, 0, 0, 0.25);
                    background-color: rgb(33, 37, 41);
                    max-width: max(400px, 100vw);
                    padding: 2rem;
                    width: min(400px, 90vw);
                }

                dialog::backdrop {
                    background-color: rgba(0, 0, 0, 0.5);
                    backdrop-filter: blur(4px);
                }

                .dialog-header {
                    color: white;
                    font-family: Inter, sans-serif;
                    font-size: 22px;
                    font-weight: 600;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding-bottom: 15px;
                    margin-bottom: 15px;
                    border-bottom: 1px solid #444;
                }

                .close {
                    all: initial;
                    background: unset;
                    padding: 5px;
                    margin: 0;
                    border: unset;
                }

                .close:not(:hover) {
                    opacity: 0.3; /* Leichte Transparenz bei Hover */
                }

                .dialog-content {
                    color: whitesmoke;
                }

            </style>

            <div data-bs-theme="dark">
                <dialog id="dialog-2">
                    <form method="dialog">
                        <div class="dialog-header">
                            <span>Info</span>
                            <button class="close">
                                <svg xmlns='http://www.w3.org/2000/svg' width="16" height="16" viewBox='0 0 16 16'
                                     fill='#CCC'>
                                    <path d='M.293.293a1 1 0 0 1 1.414 0L8 6.586 14.293.293a1 1 0 1 1 1.414 1.414L9.414 8l6.293 6.293a1 1 0 0 1-1.414 1.414L8 9.414l-6.293 6.293a1 1 0 0 1-1.414-1.414L6.586 8 .293 1.707a1 1 0 0 1 0-1.414z'/>
                                </svg>
                            </button>
                        </div>

                        <div class="dialog-content">

                        </div>
                    </form>
                </dialog>
            </div>
        `

        this.dialog = shadow.querySelector('dialog')
        this.modalContent = shadow.querySelector('.dialog-content')
    }

    showModal(callback) {
        this.dialog.showModal()
    }

    resetModal() {
        this.modalContent.innerHTML = '';
    }

    print(message) {
        let p = document.createElement('p');
        console.log("Info:", message)
        p.innerHTML = message
        this.modalContent.appendChild(p)
    }

    error(message) {
        let p = document.createElement('p');
        p.style.color = 'red'
        console.error("Error:", message)
        p.innerHTML = message
        this.modalContent.appendChild(p)
    }

    closeModal() {
        this.dialog.close()
        clearTimeout(this.closeTimer)
    }

    closeIn(time) {
        this.closeTimer = setTimeout(() => {
            this.closeModal()
        }, time)
    }
});

const infoModal = document.createElement('nzblnk-info-modal');
document.body.appendChild(infoModal);

// ------------------------------------------------------------
// settings modal

customElements.define('nzblnk-settings-modal', class NzbSettingsModal extends HTMLElement {
    #settingsRoot;

    constructor() {
        super();
        this.createModal();
        this.activeTab = 'general';
    }

    createModal() {
        const shadow = this.#settingsRoot = this.attachShadow({mode: "closed"});
        // language=HTML
        shadow.innerHTML = `
            <style>
                :host {
                    --primary-color: #0066ff;
                    --primary-dark: #0055cc;
                    --success-color: #28a745;
                    --success-dark: #218838;
                    --danger-color: #dc3545;
                    --danger-dark: #c82333;
                    --info-color: #17a2b8;
                    --info-dark: #138496;
                    --bg-dark: #212529;
                    --bg-card: #1a1d20;
                    --border-color: #444;
                    --text-color: #f5f5f5;
                    --text-muted: #aaa;
                    --shadow: 0 4px 12px rgba(0, 0, 0, 0.15), 0 2px 4px rgba(0, 0, 0, 0.12);
                    --anim-duration: 0.2s;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 16px;
                }

                * {
                    box-sizing: border-box;
                }

                /* Animations */
                @keyframes fadeIn {
                    from {
                        opacity: 0;
                    }
                    to {
                        opacity: 1;
                    }
                }

                @keyframes slideUp {
                    from {
                        transform: translateY(20px);
                        opacity: 0;
                    }
                    to {
                        transform: translateY(0);
                        opacity: 1;
                    }
                }

                @keyframes slideInRight {
                    from {
                        transform: translateX(20px);
                        opacity: 0;
                    }
                    to {
                        transform: translateX(0);
                        opacity: 1;
                    }
                }

                /* Toast notification */
                .toast {
                    position: fixed;
                    bottom: 20px;
                    right: 20px;
                    padding: 12px 20px;
                    background-color: var(--success-color);
                    color: white;
                    border-radius: 8px;
                    box-shadow: var(--shadow);
                    z-index: 9999;
                    animation: slideUp 0.3s ease-out;
                    max-width: 300px;
                }

                .toast.error {
                    background-color: var(--danger-color);
                }

                dialog {
                    border: none !important;
                    border-radius: 16px;
                    box-shadow: var(--shadow);
                    background-color: var(--bg-dark);
                    padding: 0;
                    max-height: 90vh;
                    width: 90vw;
                    max-width: 550px;
                    overflow: hidden;
                    color: var(--text-color);
                    animation: fadeIn 0.3s, slideUp 0.3s;
                }

                dialog::backdrop {
                    background-color: rgba(0, 0, 0, 0.6);
                    backdrop-filter: blur(4px);
                    animation: fadeIn 0.3s;
                }

                .dialog-container {
                    display: flex;
                    flex-direction: column;
                    height: 100%;
                    max-height: 90vh;
                }

                .dialog-header {
                    color: var(--text-color);
                    font-size: 22px;
                    font-weight: 600;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 20px 24px;
                    border-bottom: 1px solid var(--border-color);
                    background-color: rgba(0, 0, 0, 0.2);
                }

                .dialog-content {
                    flex: 1;
                    overflow-y: auto;
                    overflow-x: hidden;
                    padding: 0;
                }

                .dialog-footer {
                    padding: 16px 24px;
                    border-top: 1px solid var(--border-color);
                    background-color: rgba(0, 0, 0, 0.2);
                    display: flex;
                    justify-content: flex-end;
                }

                .close {
                    all: initial;
                    background: unset;
                    width: 36px;
                    height: 36px;
                    margin: 0;
                    border: unset;
                    border-radius: 50%;
                    cursor: pointer;
                    transition: all var(--anim-duration);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }

                .close:hover {
                    background-color: rgba(255, 255, 255, 0.1);
                    transform: scale(1.1);
                }

                .close:active {
                    transform: scale(0.95);
                }

                .close svg {
                    width: 20px;
                    height: 20px;
                    opacity: 0.8;
                    transition: opacity var(--anim-duration);
                }

                .close:hover svg {
                    opacity: 1;
                }

                .settings-content {
                    padding: 0;
                    width: 100%;
                }

                .tab-navigation {
                    display: flex;
                    background-color: rgba(0, 0, 0, 0.2);
                    padding: 4px;
                    scrollbar-width: none;
                    -ms-overflow-style: none;
                    gap: 2px;
                    overflow-x: auto;
                    min-height: 50px;
                }

                .tab-navigation::-webkit-scrollbar {
                    display: none;
                }

                .tab-button {
                    background-color: transparent;
                    color: var(--text-muted);
                    border: none;
                    padding: 0 20px;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 15px;
                    font-weight: 500;
                    transition: all var(--anim-duration);
                    white-space: nowrap;
                    flex-shrink: 0;
                }

                .tab-button:hover {
                    background-color: rgba(255, 255, 255, 0.1);
                    color: var(--text-color);
                }

                .tab-button.active {
                    background-color: var(--primary-color);
                    color: white;
                }

                .tab-content {
                    display: none;
                    padding: 24px;
                    width: 100%;
                    overflow-x: hidden;
                }

                .tab-content.active {
                    display: block;
                    animation: fadeIn 0.3s;
                }

                .settings-section {
                    margin-bottom: 32px;
                    padding-bottom: 24px;
                    border-bottom: 1px solid var(--border-color);
                    width: 100%;
                }

                .settings-section:last-child {
                    margin-bottom: 0;
                    padding-bottom: 0;
                    border-bottom: none;
                }

                .settings-section h3 {
                    margin-top: 0;
                    margin-bottom: 16px;
                    color: var(--text-color);
                    font-size: 18px;
                    font-weight: 600;
                }

                label {
                    display: block;
                    margin-bottom: 20px;
                    font-weight: 500;
                    width: 100%;
                }

                label.checkbox-label {
                    display: flex;
                    align-items: center;
                    cursor: pointer;
                }

                input[type="text"],
                input[type="password"],
                select {
                    width: 100%;
                    padding: 8px 12px;
                    margin-top: 8px;
                    background-color: rgba(255, 255, 255, 0.1);
                    border: 1px solid var(--border-color);
                    border-radius: 8px;
                    color: white;
                    font-size: 16px;
                    transition: all var(--anim-duration);
                }

                input[type="text"]:focus,
                input[type="password"]:focus,
                select:focus {
                    border-color: var(--primary-color);
                    box-shadow: 0 0 0 2px rgba(0, 102, 255, 0.25);
                    outline: none;
                }

                input[type="checkbox"] {
                    margin-right: 12px;
                    width: 20px;
                    height: 20px;
                    cursor: pointer;
                    accent-color: var(--primary-color);
                    flex-shrink: 0;
                }

                button {
                    background-color: var(--primary-color);
                    color: white;
                    border: none;
                    padding: 9.5px 15px;
                    border-radius: 8px;
                    cursor: pointer;
                    font-size: 15px;
                    font-weight: 500;
                    transition: all var(--anim-duration);
                    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
                }

                button:hover {
                    background-color: var(--primary-dark);
                    transform: translateY(-1px);
                    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                }

                button:active {
                    transform: translateY(1px);
                    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
                }

                button:disabled {
                    opacity: 0.7;
                    cursor: not-allowed;
                    transform: none;
                }

                /* Category styles */
                .category-list {
                    margin-bottom: 20px;
                    width: 100%;
                }

                .category-item {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    background-color: var(--bg-card);
                    padding: 12px 16px;
                    margin-bottom: 10px;
                    border-radius: 8px;
                    border: 1px solid var(--border-color);
                    transition: all var(--anim-duration);
                    width: 100%;
                    animation: slideInRight 0.3s;
                }

                .category-item:hover {
                    transform: translateY(-2px);
                    box-shadow: var(--shadow);
                }

                .category-item span {
                    font-size: 15px;
                    overflow: hidden;
                    text-overflow: ellipsis;
                }

                .remove-category {
                    background-color: transparent;
                    color: var(--danger-color);
                    border: none;
                    font-size: 20px;
                    width: 36px;
                    height: 36px;
                    padding: 0;
                    margin: 0;
                    cursor: pointer;
                    transition: all var(--anim-duration);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    border-radius: 50%;
                    flex-shrink: 0;
                }

                .favorite-toggle {
                    background-color: transparent;
                    color: var(--text-muted);
                    border: none;
                    font-size: 20px;
                    width: 36px;
                    height: 36px;
                    padding: 0;
                    margin: 0 6px 0 0;
                    cursor: pointer;
                    transition: all var(--anim-duration);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    border-radius: 50%;
                    flex-shrink: 0;
                }
                .favorite-toggle.active {
                    color: #f5c518;
                }
                .category-item .favorite-toggle:hover {
                    transform: translateY(-1px);
                }
                .category-item .left {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                }

                .remove-category:hover {
                    background-color: rgba(220, 53, 69, 0.1);
                    transform: scale(1.2);
                    box-shadow: none;
                }

                .load-categories {
                    background-color: var(--info-color);
                    margin-bottom: 20px;
                }

                .load-categories:hover {
                    background-color: var(--info-dark);
                }

                .action-buttons {
                    display: flex;
                    flex-wrap: wrap;
                    gap: 10px;
                    margin-top: 16px;
                }

                .action-buttons button {
                    flex: 1 1 auto;
                    min-width: 150px;
                    margin-top: 0;
                    margin-right: 0;
                }

                .save-settings {
                    background-color: var(--success-color);
                    font-weight: 600;
                    padding: 14px 24px;
                    font-size: 16px;
                    border-radius: 8px;
                }

                .save-settings:hover {
                    background-color: var(--success-dark);
                }

                .empty-message {
                    background-color: rgba(0, 0, 0, 0.2);
                    padding: 16px;
                    border-radius: 8px;
                    text-align: center;
                    color: var(--text-muted);
                    margin-bottom: 20px;
                }

                @media (max-width: 600px) {
                    dialog {
                        width: 100vw;
                        max-width: 100vw;
                        max-height: 100vh;
                        height: 100vh;
                        border-radius: 0;
                        margin: 0;
                    }

                    .dialog-header, .dialog-footer {
                        padding: 16px;
                    }

                    .tab-button {
                        padding: 12px 16px;
                        font-size: 14px;
                    }

                    .tab-content {
                        padding: 16px;
                    }

                    button {
                        padding: 14px 20px;
                        margin-right: 0;
                    }

                    .dialog-footer {
                        flex-direction: column;
                    }

                    .save-settings {
                        width: 100%;
                        margin-right: 0;
                    }

                    .category-item {
                        flex-wrap: wrap;
                        padding: 16px;
                    }

                    .category-item span {
                        width: calc(100% - 45px);
                    }

                    .toast {
                        left: 20px;
                        right: 20px;
                        max-width: unset;
                        text-align: center;
                    }
                }
            </style>

            <div>
                <dialog id="settings-dialog">
                    <form method="dialog">
                        <div class="dialog-container">
                            <div class="dialog-header">
                                <span>Einstellungen</span>
                                <button class="close" type="button">
                                    <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 16 16' fill='#CCC'>
                                        <path d='M.293.293a1 1 0 0 1 1.414 0L8 6.586 14.293.293a1 1 0 1 1 1.414 1.414L9.414 8l6.293 6.293a1 1 0 0 1-1.414 1.414L8 9.414l-6.293 6.293a1 1 0 0 1-1.414-1.414L6.586 8 .293 1.707a1 1 0 0 1 0-1.414z'/>
                                    </svg>
                                </button>
                            </div>

                            <div class="tab-navigation">
                                <button type="button" class="tab-button active" data-tab="general">Allgemein</button>
                                <button type="button" class="tab-button" data-tab="sab">SABnzbd</button>
                                <button type="button" class="tab-button" data-tab="importexport" title="Import/Export">
                                    Import/Export
                                </button>
                            </div>

                            <div class="dialog-content">
                                <div class="settings-content">
                                    <div id="general-tab" class="tab-content active">
                                        <div class="settings-section">
                                            <h3>Allgemeine Einstellungen</h3>
                                            <label>
                                                Ausgabe:
                                                <select id="ausgabe">
                                                    <option value="download">Download</option>
                                                    <option value="sabnzbd">Sabnzbd</option>
                                                    <option value="sab_menu">Sabnzbd Menü</option>
                                                </select>
                                            </label>
                                        </div>
                                        <div class="settings-section">
                                            <h3>Zusätzliche Suchdienste</h3>
                                            <label>
                                                Treasure Maps API-Key (optional)
                                                <input type="password" id="treasure_maps_api_key" autocomplete="off" autocapitalize="none" spellcheck="false">
                                            </label>
                                            <label>
                                                NewzBay API-Key (optional)
                                                <input type="password" id="newzbay_api_key" autocomplete="off" autocapitalize="none" spellcheck="false">
                                            </label>
                                            <label>
                                                NinjaCentral API-Key (optional)
                                                <input type="password" id="ninjacentral_api_key" autocomplete="off" autocapitalize="none" spellcheck="false">
                                            </label>
                                            <label>
                                                DrunkenSlug API-Key (optional)
                                                <input type="password" id="drunkenslug_api_key" autocomplete="off" autocapitalize="none" spellcheck="false">
                                            </label>
                                            <label>
                                                NZBFinder API-Key (optional)
                                                <input type="password" id="nzbfinder_api_key" autocomplete="off" autocapitalize="none" spellcheck="false">
                                            </label>
                                            <label>
                                                Videothek.io API-Key (optional)
                                                <input type="password" id="videothek_api_key" autocomplete="off" autocapitalize="none" spellcheck="false">
                                            </label>
                                            <p>Videothek.io erfordert Premium und muss NZBPort/nzb-load in der Tool-Allowlist erlauben. Ohne API-Key wird der Dienst übersprungen.</p>
                                            <p>Bei Bedarf sucht das Script bei Treasure Maps, NewzBay, NinjaCentral, DrunkenSlug, NZBFinder und Videothek.io nach dem Releasetitel.</p>
                                        </div>
                                    </div>

                                    <div id="sab-tab" class="tab-content">
                                        <div class="settings-section">
                                            <h3>SABnzbd Verbindung</h3>
                                            <label>
                                                SABnzbd URL:
                                                <input type="text" id="sab_url" placeholder="http://localhost:8080/api">
                                            </label>
                                            <label>
                                                SABnzbd API Key:
                                                <input type="password" id="sab_api_key">
                                            </label>
                                        </div>

                                        <div class="settings-section" id="sab_default_category-section">
                                            <label id="sab_default_category-label">
                                                Standard Kategorie:
                                                <input type="text" id="sab_default_category" placeholder="*">
                                            </label>
                                        </div>

                                        <div class="settings-section" id="sab-cat-list">
                                            <h3>Kategorien</h3>

                                            <label class="checkbox-label">
                                                <input type="checkbox" id="sab_sub_menu">
                                                SAB Buttons als Untermenü anzeigen
                                            </label>

                                            <div id="sab-categories-container"></div>
                                            
                                            <button type="button" class="load-categories">Kategorien von SABnzbd laden
                                            </button>
                                        </div>
                                    </div>

                                    <div id="importexport-tab" class="tab-content">
                                        <div class="settings-section">
                                            <h3>Import/Export Einstellungen</h3>
                                            <div class="action-buttons">
                                                <button type="button" class="export-settings">Exportieren</button>
                                                <input type="file" accept="application/json" style="display:none"
                                                       class="import-file-input">
                                                <button type="button" class="import-settings">Importieren</button>
                                            </div>

                                            <div class="import-result" style="margin-top:10px;color:#aaa;"></div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div class="dialog-footer">
                                <button type="button" class="save-settings">Einstellungen speichern</button>
                            </div>
                        </div>
                    </form>
                </dialog>
            </div>
        `;

        // Tabs and Basic Elements
        this.tabButtons = shadow.querySelectorAll('.tab-button');
        this.tabContents = shadow.querySelectorAll('.tab-content');
        this.closeButton = shadow.querySelector('.close');
        this.dialog = shadow.querySelector('#settings-dialog');
        this.saveButton = shadow.querySelector('.save-settings');

        // Sab
        this.sabCategoriesContainer = shadow.querySelector('#sab-categories-container');
        this.loadCategoriesButton = shadow.querySelector('.load-categories');

        // Import/Export
        this.exportButton = shadow.querySelector('.export-settings');
        this.importButton = shadow.querySelector('.import-settings');
        this.importFileInput = shadow.querySelector('.import-file-input');
        this.importResult = shadow.querySelector('.import-result');

        // Event-Listener einrichten
        this.setupEventListeners();
    }

    setupEventListeners() {
        // Select-Change-Event für Ausgabe-Typ
        this.#settingsRoot.querySelector('#ausgabe').addEventListener('change', () => this.updateShowAndHidden());

        // Tab-Navigation
        this.tabButtons.forEach(button => {
            button.addEventListener('click', (e) => {
                const tabName = e.target.getAttribute('data-tab');
                this.switchTab(tabName);
            });
        });

        // Schließen-Button im Dialog
        this.closeButton.addEventListener('click', () => this.closeModal());

        // Buttons-Events
        this.saveButton.addEventListener('click', () => this.saveSettings());
        this.loadCategoriesButton.addEventListener('click', () => this.loadCategoriesFromSAB());

        // Verhindern, dass Events an die Seite weitergegeben werden
        this.dialog.addEventListener('keydown', this.stopPropagation);
        this.dialog.addEventListener('keyup', this.stopPropagation);
        this.dialog.addEventListener('keypress', this.stopPropagation);
        this.dialog.addEventListener('mousedown', this.stopPropagation);
        this.dialog.addEventListener('mouseup', this.stopPropagation);
        this.dialog.addEventListener('click', this.stopPropagation);

        // Import/Export Events
        if (this.exportButton) {
            this.exportButton.addEventListener('click', () => this.handleExportSettings());
        }
        if (this.importButton) {
            this.importButton.addEventListener('click', () => this.importFileInput.click());
        }
        if (this.importFileInput) {
            this.importFileInput.addEventListener('change', (e) => this.handleImportSettings(e));
        }
    }

    stopPropagation(e) {
        e.stopPropagation();
    }

    showToast(message, isError = false) {
        // Alte Toast-Nachricht entfernen, falls vorhanden
        const oldToast = this.#settingsRoot.querySelector('.toast');
        if (oldToast) {
            oldToast.remove();
        }

        // Neue Toast-Nachricht erstellen
        const toast = document.createElement('div');
        toast.className = `toast ${isError ? 'error' : ''}`;
        toast.textContent = message;

        this.dialog.appendChild(toast);

        // Toast nach 3 Sekunden automatisch ausblenden
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(20px)';
            toast.style.transition = 'opacity 0.3s, transform 0.3s';

            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    // Import / Export Settings

    handleExportSettings() {
        const settings = {
            // Allgemeine Einstellungen
            ausgabe: this.#settingsRoot.querySelector('#ausgabe').value,
            treasure_maps_api_key: this.#settingsRoot.querySelector('#treasure_maps_api_key').value.trim(),
            newzbay_api_key: this.#settingsRoot.querySelector('#newzbay_api_key').value.trim(),
            ninjacentral_api_key: this.#settingsRoot.querySelector('#ninjacentral_api_key').value.trim(),
            drunkenslug_api_key: this.#settingsRoot.querySelector('#drunkenslug_api_key').value.trim(),
            nzbfinder_api_key: this.#settingsRoot.querySelector('#nzbfinder_api_key').value.trim(),
            videothek_api_key: this.#settingsRoot.querySelector('#videothek_api_key').value.trim(),

            // SABnzbd-Einstellungen
            sab_url: this.#settingsRoot.querySelector('#sab_url').value,
            sab_api_key: this.#settingsRoot.querySelector('#sab_api_key').value,
            sab_default_category: this.#settingsRoot.querySelector('#sab_default_category').value,
            sab_sub_menu: this.#settingsRoot.querySelector('#sab_sub_menu').checked,
            sab_categories: SETTINGS.sab_categories || [],
            sab_hidden_categories: [...SETTINGS.sab_hidden_categories],

        };

        saveFile({
            fileName: 'nzb-loader-settings',
            fileType: 'application/json',
            responseText: JSON.stringify(settings, null, 2),
            fileExtension: '.json'
        })
    }

    handleImportSettings(e) {
        const file = e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const settings = JSON.parse(e.target.result);
                Object.assign(SETTINGS, supportedSettings(settings));
                this.loadCurrentSettings();

                this.importResult.textContent = 'Einstellungen erfolgreich importiert';
                this.importResult.style.color = 'var(--success-color)';
            } catch (error) {
                this.importResult.textContent = 'Fehler beim Import: ' + error.message;
                this.importResult.style.color = 'var(--danger-color)';
            }
        };
        reader.readAsText(file);
    }

    // Modal Things

    updateShowAndHidden() {
        const ausgabeValue = this.#settingsRoot.querySelector('#ausgabe').value;

        // tabs
        const sabnzbd_tab_button = this.#settingsRoot.querySelector('.tab-button[data-tab="sab"]');

        // sections
        const sab_default_cat = this.#settingsRoot.querySelector('#sab_default_category-section');
        const sab_cat_list = this.#settingsRoot.querySelector('#sab-cat-list');


        if (ausgabeValue === 'sab_menu') {
            sab_default_cat.style.display = 'none';
            sab_cat_list.style.display = 'block';
        } else {
            sab_default_cat.style.display = 'block';
            sab_cat_list.style.display = 'none';
        }

        if (ausgabeValue === 'sab_menu' || ausgabeValue === 'sabnzbd') {
            sabnzbd_tab_button.style.display = 'block';
        } else {
            sabnzbd_tab_button.style.display = 'none';
        }


    }

    async showModal() {
        if (!await settingsReady) {
            alert('Einstellungen konnten nicht geladen werden. Bitte die Seite neu laden.');
            return;
        }
        if (this.dialog.open) return;
        // Event-Listener für die globalen Tastatur-Events
        document.addEventListener('keydown', this.globalKeydownHandler = (e) => {
            // Verhindern, dass bestimmte Tastenkombinationen durchsickern
            if ((e.ctrlKey || e.metaKey || e.altKey) ||
                ['Escape', 'Enter', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(e.key)) {
                // Erlauben Sie Tab innerhalb des Dialogs, aber stoppen Sie die Propagation
                if (e.key === 'Tab' && this.dialog.open) {
                    // Erlaube Tab-Navigation innerhalb des Dialogs
                    return;
                }
                e.stopPropagation();
            }
        }, true);

        this.loadCurrentSettings();
        this.updateShowAndHidden();
        this.dialog.showModal();

        // Fokus auf das erste Element im Dialog setzen, um Tastaturbedienung zu erleichtern
        setTimeout(() => {
            const firstInput = this.#settingsRoot.querySelector('select, input, button:not(.close)');
            if (firstInput) {
                firstInput.focus();
            }
        }, 100);
    }

    closeModal() {
        // Event-Listener für globale Tastatur-Events entfernen
        if (this.globalKeydownHandler) {
            document.removeEventListener('keydown', this.globalKeydownHandler, true);
            this.globalKeydownHandler = null;
        }

        this.dialog.close();
    }

    showSabTab() {
        this.#settingsRoot.querySelector('#ausgabe').value = 'sab_menu';
        this.updateShowAndHidden();
        this.switchTab('sab');
    }

    switchTab(tabName) {
        this.activeTab = tabName;

        // Tab-Buttons aktualisieren
        this.tabButtons.forEach(button => {
            button.classList.toggle('active', button.getAttribute('data-tab') === tabName);
        });

        // Tab-Inhalte aktualisieren
        this.tabContents.forEach(content => {
            content.classList.toggle('active', content.id === `${tabName}-tab`);
        });

        // Export-Textarea ausblenden, wenn Tab gewechselt wird
        if (this.importResult) this.importResult.textContent = '';
    }

    // Categories show edit and remove

    renderCategories() {
        this.sabCategoriesContainer.innerHTML = '';

        if (SETTINGS.sab_categories && SETTINGS.sab_categories.length > 0) {
            const categoryList = document.createElement('div');
            categoryList.className = 'category-list';

            SETTINGS.sab_categories.forEach((category, index) => {
                const categoryItem = document.createElement('div');
                categoryItem.className = 'category-item';

                const name = (category && typeof category === 'object') ? category.value : String(category);
                const isFav = !!(category && category.fav);
                categoryItem.innerHTML = `
                    <div class="left">
                        <button type="button" class="favorite-toggle ${isFav ? 'active' : ''}" data-index="${index}" title="Favorit umschalten">${isFav ? '★' : '☆'}</button>
                        <span>${name}</span>
                    </div>
                    <button type="button" class="remove-category" data-index="${index}">×</button>
                `;
                categoryList.appendChild(categoryItem);

                // Event-Listener zum Favorisieren-Button
                const favoriteButton = categoryItem.querySelector('.favorite-toggle');
                favoriteButton.addEventListener('click', () => this.toggleFavoriteCategory(index));

                // Event-Listener zum Entfernen-Button
                const removeButton = categoryItem.querySelector('.remove-category');
                removeButton.addEventListener('click', () => this.removeCategory(index));
            });

            this.sabCategoriesContainer.appendChild(categoryList);
        } else {
            const emptyMessage = document.createElement('div');
            emptyMessage.className = 'empty-message';
            emptyMessage.innerHTML = `
                <p>Keine Kategorien definiert</p>
                <p>Lade die Kategorien von SABnzbd oder blende eine Kategorie wieder ein.</p>
            `;
            this.sabCategoriesContainer.appendChild(emptyMessage);
        }

        if (SETTINGS.sab_hidden_categories.length > 0) {
            const heading = document.createElement('h3');
            heading.textContent = 'Ausgeblendete Kategorien';
            this.sabCategoriesContainer.appendChild(heading);

            SETTINGS.sab_hidden_categories.forEach(categoryName => {
                const row = document.createElement('div');
                row.className = 'category-item';
                const name = document.createElement('span');
                name.textContent = categoryName;
                const restore = document.createElement('button');
                restore.type = 'button';
                restore.textContent = 'Wieder einblenden';
                restore.addEventListener('click', () => this.restoreCategory(categoryName));
                row.appendChild(name);
                row.appendChild(restore);
                this.sabCategoriesContainer.appendChild(row);
            });
        }
    }

    restoreCategory(categoryName) {
        SETTINGS.sab_hidden_categories = SETTINGS.sab_hidden_categories.filter(
            name => name.toLowerCase() !== categoryName.toLowerCase()
        );
        if (!SETTINGS.sab_categories.some(category =>
            category.value.toLowerCase() === categoryName.toLowerCase())) {
            SETTINGS.sab_categories.push({ value: categoryName, fav: false });
        }
        this.renderCategories();
        this.showToast('Kategorie wieder eingeblendet. Bitte Einstellungen speichern.');
    }

    removeCategory(index) {
        const cat = SETTINGS.sab_categories[index];
        const categoryName = (cat && typeof cat === 'object') ? cat.value : String(cat);

        const confirmRemove = confirm(`Kategorie "${categoryName}" im Auswahlmenü ausblenden? In SABnzbd bleibt sie erhalten.`);

        if (confirmRemove) {
            if (!SETTINGS.sab_hidden_categories.some(name =>
                name.toLowerCase() === categoryName.toLowerCase())) {
                SETTINGS.sab_hidden_categories.push(categoryName);
            }
            SETTINGS.sab_categories.splice(index, 1);
            this.renderCategories();
            this.showToast(`Kategorie "${categoryName}" ausgeblendet. Bitte Einstellungen speichern.`);
        }
    }

    toggleFavoriteCategory(index) {
        const cat = SETTINGS.sab_categories[index];
        if (!cat) return;
        cat.fav = !cat.fav;
        const name = (cat && typeof cat === 'object') ? cat.value : String(cat);
        if (cat.fav) {
            this.showToast(`"${name}" zu Favoriten hinzugefügt`);
        } else {
            this.showToast(`"${name}" aus Favoriten entfernt`);
        }
        this.renderCategories();
    }

    loadCategoriesFromSAB() {
        let sab_url = this.#settingsRoot.querySelector('#sab_url').value || SETTINGS.sab_url || '';
        let sab_api_key = this.#settingsRoot.querySelector('#sab_api_key').value || SETTINGS.sab_api_key || '';

        if (!sab_url || !sab_api_key) {
            this.showToast('Bitte gib zuerst die SABnzbd URL und den API-Key ein', true);
            return;
        }

        this.loadCategoriesButton.textContent = 'Lade...';
        this.loadCategoriesButton.disabled = true;

        SABNZBD.getCategories({
            url: sab_url,
            key: sab_api_key,
            callback: (categories) => {
                if (categories && categories.length > 0) {
                    refreshSabCategories(categories);
                    this.renderCategories();
                    this.showToast(`${categories.length} Kategorien von SABnzbd geladen`);
                } else {
                    this.showToast('Keine Kategorien in SABnzbd gefunden', true);
                }
                this.loadCategoriesButton.textContent = 'Kategorien von SABnzbd laden';
                this.loadCategoriesButton.disabled = false;
            },
            failed_callback: (error) => {
                console.error('Fehler beim Laden der Kategorien:', error);
                this.showToast('Fehler beim Laden der Kategorien. Bitte überprüfe die SABnzbd Einstellungen.', true);
                this.loadCategoriesButton.textContent = 'Kategorien von SABnzbd laden';
                this.loadCategoriesButton.disabled = false;
            }
        });
    }

    // Settings save and load

    loadCurrentSettings() {
        // Allgemeine Einstellungen laden
        const ausgabeSelect = this.#settingsRoot.querySelector('#ausgabe');

        ausgabeSelect.value = SETTINGS.ausgabe || 'sab_menu';
        this.#settingsRoot.querySelector('#treasure_maps_api_key').value = SETTINGS.treasure_maps_api_key || '';
        this.#settingsRoot.querySelector('#newzbay_api_key').value = SETTINGS.newzbay_api_key || '';
        this.#settingsRoot.querySelector('#ninjacentral_api_key').value = SETTINGS.ninjacentral_api_key || '';
        this.#settingsRoot.querySelector('#drunkenslug_api_key').value = SETTINGS.drunkenslug_api_key || '';
        this.#settingsRoot.querySelector('#nzbfinder_api_key').value = SETTINGS.nzbfinder_api_key || '';
        this.#settingsRoot.querySelector('#videothek_api_key').value = SETTINGS.videothek_api_key || '';

        // SABnzbd-Einstellungen laden
        this.#settingsRoot.querySelector('#sab_url').value = SETTINGS.sab_url || '';
        this.#settingsRoot.querySelector('#sab_api_key').value = SETTINGS.sab_api_key || '';
        this.#settingsRoot.querySelector('#sab_default_category').value = SETTINGS.sab_default_category || '';
        this.#settingsRoot.querySelector('#sab_sub_menu').checked = SETTINGS.sab_sub_menu || false;

        // SAB-Kategorien laden
        this.renderCategories();
    }

    saveSettings() {
        const newSettings = {
            // Allgemeine Einstellungen
            ausgabe: this.#settingsRoot.querySelector('#ausgabe').value,
            treasure_maps_api_key: this.#settingsRoot.querySelector('#treasure_maps_api_key').value.trim(),
            newzbay_api_key: this.#settingsRoot.querySelector('#newzbay_api_key').value.trim(),
            ninjacentral_api_key: this.#settingsRoot.querySelector('#ninjacentral_api_key').value.trim(),
            drunkenslug_api_key: this.#settingsRoot.querySelector('#drunkenslug_api_key').value.trim(),
            nzbfinder_api_key: this.#settingsRoot.querySelector('#nzbfinder_api_key').value.trim(),
            videothek_api_key: this.#settingsRoot.querySelector('#videothek_api_key').value.trim(),

            // SABnzbd-Einstellungen
            sab_url: this.#settingsRoot.querySelector('#sab_url').value,
            sab_api_key: this.#settingsRoot.querySelector('#sab_api_key').value,
            sab_default_category: this.#settingsRoot.querySelector('#sab_default_category').value,
            sab_sub_menu: this.#settingsRoot.querySelector('#sab_sub_menu').checked,
            sab_categories: SETTINGS.sab_categories || [],
            sab_hidden_categories: [...SETTINGS.sab_hidden_categories],

        };

        // Einstellungen speichern
        saveSettings(newSettings).then(() => {
            // Zugangsdaten werden nicht in die Konsole geschrieben.

            // Speicher-Animation
            this.saveButton.disabled = true;
            this.saveButton.textContent = 'Gespeichert!';
            this.saveButton.style.backgroundColor = 'var(--success-color)';

            // Bestätigung anzeigen
            this.showToast('Einstellungen gespeichert! Seite wird neu geladen...');

            // reload site
            setTimeout(() => {
                location.reload();
            }, 2000);
        }).catch(error => {
            this.showToast(error.message, true);
        });


    }
});

const settingsModal = document.createElement('nzblnk-settings-modal');
document.body.appendChild(settingsModal);

// ------------------------------------------------------------
// nzb handler

function parseNzblnkUrl(url) {
    // Entferne 'nzblnk:?' vom Anfang der URL
    let paramsString = url.slice(url.indexOf("?") + 1);

    // Analysiere die Parameter
    const params = new URLSearchParams(paramsString);

    // Füge die Parameter zu einem Objekt hinzu
    let result = {};
    for (let param of params) {
        result[param[0]] = param[1];
    }

    return result;
}

// ------------------------------------------------------------
// load from ...

function loadFromNzbKing(nzb_info, when_failed) {
    console.log("Suche auf nzbking.com")
    GM_xmlhttpRequest({
        method: "GET",
        url: "https://www.nzbking.com/?q=" + encodeURIComponent(nzb_info.h || ''),
        timeout: 15000,
        onload: function (response) {
            if (response.status !== 200) return when_failed();
            console.log("King:", response)
            let parser = new DOMParser();
            let doc = parser.parseFromString(response.responseText, 'text/html');

            const nzbLink = doc.querySelector('a[href^="/nzb:"]');
            if (nzbLink) {
                console.log("Auf nzbking gefunden");
                handleNzb("https://www.nzbking.com" + nzbLink.getAttribute('href'), nzb_info.t, nzb_info.p)
                return;
            }

            return when_failed()
        },
        onerror: function () {
            console.error("Request zu NzbKing fehlgeschlagen")
            when_failed()
        },
        ontimeout: when_failed
    });
}

function loadFromNzbIndex(nzb_info, when_failed) {
    console.log("Suche auf nzbindex.com")
    let url = `https://nzbindex.com/api/search?q=${encodeURIComponent(nzb_info.h || '')}&max=5&sort=agedesc`

    GM_xmlhttpRequest({
        method: "GET",
        url: url,
        timeout: 15000,
        onload: function (response) {
            if (response.status !== 200) return when_failed();
            let data;
            try { data = JSON.parse(response.responseText); }
            catch { return when_failed(); }

            if (!data?.data) {
                console.error("Irgengendwas ist komisch bei nzbindex.com")
                console.log(data)
                return when_failed()
            }

            data = data.data

            if (data.page?.totalElements === 0) {
                console.log("Nichts auf nzbindex.com gefunden")
                return when_failed()
            }

            if (!Array.isArray(data.content)) {
                console.log("Keine Ergebnisse auf nzbindex.com gefunden - result is undefined")
                return when_failed()
            }

            if (data.content.length === 0) {
                console.log("Keine Ergebnisse auf nzbindex.com gefunden - result is empty")
                return when_failed()
            }

            if (!data.content[0]?.id) {
                console.log("Id ist nicht gesetzt bei nzbindex.com")
                return when_failed()
            }

            let ids = data.content.map(item => item.id).join(',');

            console.log("Auf nzbindex.com gefunden")
            handleNzb("https://nzbindex.com/download?ids=" + ids, nzb_info.t, nzb_info.p)
        },
        onerror: function (response) {
            console.log("Request zu nzbindex.com fehlgeschlagen")
            console.error(response)
            return when_failed()
        },
        ontimeout: when_failed
    });
}

function loadFromBinSearch(nzb_info, when_failed) {
    console.log("Suche auf binsearch.com")
    let url = `https://www.binsearch.info/search?q=${encodeURIComponent(nzb_info.h || '')}&max=5`

    GM_xmlhttpRequest({
        method: "GET",
        url: url,
        timeout: 15000,
        onload: function (response) {
            if (response.status !== 200) return when_failed();
            console.log("binsearch:", response)
            const parser = new DOMParser();
            const doc = parser.parseFromString(response.responseText, 'text/html');

            const el = doc.querySelector("form[action*='nzb'] input[type='checkbox']")

            if (!el) {
                console.log("Keine ID auf binsearch.info gefunden!")
                return when_failed()
            }

            const id = el.getAttribute('name')

            console.log("Auf binsearch.info gefunden")
            handleNzb(`https://www.binsearch.info/nzb?${id}=on`, nzb_info.t, nzb_info.p)
        },
        onerror: function (response) {
            console.log("Request zu binsearch.info fehlgeschlagen")
            console.error(response)
            return when_failed()
        },
        ontimeout: when_failed
    });
}

class IndexerRequestError extends Error {}

function indexerRequest(url, accept, allowedRedirectHost = null, extraHeaders = {}) {
    return new Promise((resolve, reject) => {
        const fail = message => reject(new IndexerRequestError(message));
        const noResponse = () => fail(`Keine HTTP-Antwort. Prüfe in Safari, ob Userscripts Zugriff auf ${url.hostname} hat.`);
        const receive = response => {
            const status = Number(response?.status) || 0;
            const destination = response?.responseURL || response?.finalUrl;
            if (status === 0) {
                noResponse();
            } else if (status === 429) {
                fail('Das API-Anfragelimit ist erreicht (HTTP 429).');
            } else if (status === 401 || status === 403) {
                if (url.hostname === 'nzbfinder.ws' && status === 401 &&
                    typeof response?.responseText === 'string' && response.responseText.length <= 65536) {
                    try {
                        const root = new DOMParser().parseFromString(response.responseText, 'application/xml').documentElement;
                        if (root?.localName === 'error' && root.getAttribute('code') === '102') {
                            fail('NZBFinder benötigt für den API-Zugriff eine Premium-Mitgliedschaft. Details: https://nzbfinder.ws/premium');
                            return;
                        }
                    } catch {}
                }
                fail(`Zugriff abgelehnt (HTTP ${status}). Prüfe den API-Key und die Berechtigungen deines Kontos.`);
            } else if (status !== 200) {
                fail(`Der Suchdienst meldet HTTP ${status}.`);
            } else if (destination) {
                let finalURL = parseIndexerURL(destination);
                if (!finalURL && allowedRedirectHost) {
                    try { finalURL = new URL(destination, url); }
                    catch {}
                }
                const redirectAllowed = allowedRedirectHost && finalURL?.protocol === 'https:' &&
                    finalURL.hostname === allowedRedirectHost && !finalURL.username && !finalURL.password &&
                    (!finalURL.port || finalURL.port === '443') && !finalURL.hash;
                if (allowedRedirectHost ? !redirectAllowed : finalURL?.origin !== url.origin) {
                    fail('Der Suchdienst hat auf eine andere Domain umgeleitet.');
                    return;
                }
                resolve(response.responseText ?? response.response);
            } else {
                resolve(response.responseText ?? response.response);
            }
        };
        const request = {
            method: 'GET',
            url: url.href,
            headers: { Accept: accept, ...extraHeaders },
            responseType: 'text',
            timeout: 30000,
            onload: receive,
            onerror: response => {
                if (Number(response?.status) >= 400) receive(response);
                else noResponse();
            },
            ontimeout: () => fail('Der Suchdienst hat innerhalb von 30 Sekunden nicht geantwortet.'),
            onabort: () => fail('Safari oder Userscripts hat die Anfrage abgebrochen.')
        };
        try { GM_xmlhttpRequest(request); }
        catch { fail('Userscripts konnte die Anfrage nicht starten.'); }
    });
}

function parseIndexerURL(value) {
    try { return new URL(value); }
    catch { return null; }
}

function indexerXML(text, maxLength) {
    if (typeof text !== 'string' || text.length > maxLength || /<!ENTITY\s/i.test(text)) {
        throw new Error('Die Antwort des Suchdienstes hat ein ungültiges Format.');
    }
    const root = new DOMParser().parseFromString(text, 'application/xml').documentElement;
    if (!root || root.localName === 'parsererror' || root.querySelector('parsererror')) {
        throw new Error('Die Antwort des Suchdienstes hat ein ungültiges Format.');
    }
    return root;
}

function normalizedReleaseTitle(title) {
    return title.toLowerCase().replace(/[._\s]+/g, ' ').trim();
}

const releaseID = /^[a-f0-9]{32}$/i;

function treasureMapsDownload(item) {
    const raw = item.querySelector('enclosure[type="application/x-nzb"]')?.getAttribute('url');
    if (!raw) return;
    const url = parseIndexerURL(raw);
    if (!url) return;
    const params = [...url.searchParams];
    if (url.origin === 'https://file.treasure-maps.com' && !url.username && !url.password && !url.hash &&
        /^\/getnzb\/[a-f0-9]{32}$/i.test(url.pathname) && params.length === 1 && params[0][0] === 'r' && params[0][1]) {
        return url;
    }
}

function newzBayDownload(item, apiKey) {
    const guidAttribute = [...item.getElementsByTagNameNS('http://www.newznab.com/DTD/2010/feeds/attributes/', 'attr')]
        .find(attribute => attribute.getAttribute('name') === 'guid')?.getAttribute('value');
    const guid = item.querySelector('guid');
    for (const value of [guidAttribute, guid?.textContent, guid?.getAttribute('id'), item.getAttribute('guid')]) {
        if (!value) continue;
        const text = value.trim();
        let id = text;
        if (!releaseID.test(id)) {
            const source = parseIndexerURL(text);
            if (source?.origin !== 'https://newzbay.cc' || source.username || source.password) continue;
            id = source.pathname === '/api' ? source.searchParams.get('id') : source.pathname.match(/^\/details\/([^/]+)$/)?.[1];
        }
        if (id && releaseID.test(id)) {
            const download = new URL('https://newzbay.cc/api');
            download.search = new URLSearchParams({ t: 'get', id, apikey: apiKey });
            return download;
        }
    }
}

function ninjaCentralDownload(item, apiKey) {
    const guidAttribute = [...item.getElementsByTagNameNS('http://www.newznab.com/DTD/2010/feeds/attributes/', 'attr')]
        .find(attribute => attribute.getAttribute('name') === 'guid')?.getAttribute('value');
    const guid = item.querySelector('guid');
    const validID = value => /^[a-f0-9]{32}$/i.test(value || '');
    for (const value of [guidAttribute, guid?.textContent, guid?.getAttribute('id'), item.getAttribute('guid')]) {
        if (!value) continue;
        const text = value.trim();
        let id = text;
        if (!validID(id)) {
            const source = parseIndexerURL(text);
            if (source?.origin !== 'https://ninjacentral.co.za' || source.username || source.password) continue;
            id = source.pathname.match(/^\/details\/([^/]+)\/?$/)?.[1];
        }
        if (validID(id)) {
            const download = new URL('https://ninjacentral.co.za/api');
            download.search = new URLSearchParams({ t: 'get', id, apikey: apiKey });
            return download;
        }
    }
}

const nzbFinderID = /^(?:[a-f0-9]{32}|[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/i;

function nzbFinderDownload(item, apiKey) {
    const attrNS = 'http://www.newznab.com/DTD/2010/feeds/attributes/';
    const attrs = [...item.getElementsByTagNameNS(attrNS, 'attr')];
    const guidAttribute = attrs.find(attribute => attribute.getAttribute('name') === 'guid')?.getAttribute('value');
    const detailsAttribute = attrs.find(attribute => ['details', 'detailsurl', 'detailsUrl'].includes(attribute.getAttribute('name')))?.getAttribute('value');
    const guid = item.querySelector('guid');
    const detailsLink = item.querySelector('link')?.textContent;
    for (const value of [guidAttribute, guid?.textContent, guid?.getAttribute('id'), item.getAttribute('guid'), detailsAttribute, detailsLink]) {
        if (!value) continue;
        const text = value.trim();
        let id = text;
        if (!nzbFinderID.test(id)) {
            const source = parseIndexerURL(text);
            if (source?.origin !== 'https://nzbfinder.ws' || source.username || source.password || source.hash) continue;
            id = source.pathname === '/api' ? source.searchParams.get('id')
                : source.pathname.match(/^\/details\/([^/]+)\/?$/)?.[1];
        }
        if (id && nzbFinderID.test(id)) {
            const download = new URL('https://nzbfinder.ws/api');
            download.search = new URLSearchParams({ t: 'get', id, apikey: apiKey });
            return download;
        }
    }
}

function drunkenSlugDownload(item, apiKey) {
    const guidAttribute = [...item.getElementsByTagNameNS('http://www.newznab.com/DTD/2010/feeds/attributes/', 'attr')]
        .find(attribute => attribute.getAttribute('name') === 'guid')?.getAttribute('value');
    const guid = item.querySelector('guid');
    for (const value of [guidAttribute, guid?.textContent, guid?.getAttribute('id'), item.getAttribute('guid')]) {
        if (!value) continue;
        const text = value.trim();
        let id = text;
        if (!releaseID.test(id)) {
            const source = parseIndexerURL(text);
            if (source?.origin !== 'https://drunkenslug.com' || source.username || source.password) continue;
            id = source.pathname === '/api' ? source.searchParams.get('id')
                : source.pathname.match(/^\/details\/([^/]+)\/?$/)?.[1];
        }
        if (id && releaseID.test(id)) {
            const download = new URL('https://drunkenslug.com/api');
            download.search = new URLSearchParams({ t: 'get', id, apikey: apiKey });
            return download;
        }
    }
}

const videothekID = /^(?:[a-f0-9]{32}|[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})$/i;

function videothekDownload(item, apiKey) {
    const attrNS = 'http://www.newznab.com/DTD/2010/feeds/attributes/';
    const attrs = [...item.getElementsByTagNameNS(attrNS, 'attr')];
    const guidAttribute = attrs.find(attribute => attribute.getAttribute('name') === 'guid')?.getAttribute('value');
    const guid = item.querySelector('guid');
    const detailsAttribute = attrs.find(attribute => ['details', 'detailsurl', 'detailsUrl'].includes(attribute.getAttribute('name')))?.getAttribute('value');
    for (const value of [guidAttribute, guid?.textContent, guid?.getAttribute('id'), item.getAttribute('guid'), detailsAttribute]) {
        if (!value) continue;
        const text = value.trim();
        let id = text;
        if (!videothekID.test(id)) {
            const source = parseIndexerURL(text);
            if (source?.origin !== 'https://videothek.io' || source.username || source.password || source.hash) continue;
            id = source.pathname === '/api' ? source.searchParams.get('id')
                : source.pathname.match(/^\/details\/([^/]+)\/?$/)?.[1];
        }
        if (id && videothekID.test(id)) {
            const download = new URL('https://videothek.io/api');
            download.search = new URLSearchParams({ t: 'get', id, apikey: apiKey, o: 'xml' });
            return download;
        }
    }
}

const additionalIndexers = [
    { info: 'Treasure Maps', key: 'treasure_maps_api_key', endpoint: 'https://treasure-maps.com/api', download: treasureMapsDownload },
    { info: 'NewzBay', key: 'newzbay_api_key', endpoint: 'https://newzbay.cc/api', download: newzBayDownload },
    { info: 'NinjaCentral', key: 'ninjacentral_api_key', endpoint: 'https://ninjacentral.co.za/api', download: ninjaCentralDownload, allowRedirectHost: 'ninjacentral.co.za' },
    { info: 'DrunkenSlug', key: 'drunkenslug_api_key', endpoint: 'https://drunkenslug.com/api', download: drunkenSlugDownload },
    { info: 'NZBFinder', key: 'nzbfinder_api_key', endpoint: 'https://nzbfinder.ws/api', download: nzbFinderDownload, userAgent: 'nzb-load/2.3.6 (NZB link search; iOS Userscripts)' },
    { info: 'Videothek.io', key: 'videothek_api_key', endpoint: 'https://videothek.io/api', download: videothekDownload, userAgent: 'NZBPort/nzb-load/2.3.7 (NZB link search; iOS Userscripts)', xmlOutput: true, apiErrors: true }
];

async function loadFromNewznab(indexer, apiKey, nzb_info, when_failed) {
    const title = normalizedReleaseTitle(nzb_info.t || '');
    if (!title) return when_failed();
    const url = new URL(indexer.endpoint);
    url.search = new URLSearchParams({ t: 'search', q: nzb_info.t, apikey: apiKey });
    if (indexer.xmlOutput || indexer.info === 'NewzBay' || indexer.info === 'NinjaCentral' || indexer.info === 'DrunkenSlug') url.searchParams.set('o', 'xml');

    const headers = indexer.userAgent ? { 'User-Agent': indexer.userAgent } : {};
    let download;
    try {
        const responseText = await indexerRequest(url, 'application/rss+xml, application/xml, text/xml', null, headers);
        const rss = indexerXML(responseText, 2 * 1024 * 1024);
        if (rss.localName === 'error') {
            if (indexer.apiErrors) {
                const code = rss.getAttribute('code') || 'unbekannt';
                const description = rss.getAttribute('description') || rss.getAttribute('message') || rss.textContent.trim();
                throw new Error(`Videothek.io API-Fehler ${code}${description ? `: ${description}` : ''}. Premium und die Freigabe von NZBPort/nzb-load in der Tool-Allowlist sind erforderlich.`);
            }
            throw new Error('Die Suche wurde abgelehnt. Prüfe den API-Key und die Berechtigungen deines Kontos.');
        }
        if (rss.localName !== 'rss' || !rss.querySelector('channel')) {
            throw new Error('Die Suchantwort hat ein ungültiges Format.');
        }
        const matches = [...rss.querySelectorAll('channel > item')].filter(item =>
            normalizedReleaseTitle(item.querySelector('title')?.textContent || '') === title);
        if (!matches.length) return when_failed();
        if (matches.length !== 1) throw new Error('Mehrere Treffer haben denselben Releasetitel.');
        download = indexer.download(matches[0], apiKey);
        if (!download) throw new Error('Der Treffer enthält keine gültige NZB-Adresse oder ID.');
    } catch (error) {
        const message = document.createElement('p');
        message.textContent = `${indexer.info}: ${error.message}`;
        infoModal.modalContent.appendChild(message);
        return when_failed();
    }

    const fetchNZB = async () => {
        const text = await indexerRequest(download, 'application/x-nzb, application/xml, text/xml', indexer.allowRedirectHost, headers);
        const root = indexerXML(text, 16 * 1024 * 1024);
        if (root.localName !== 'nzb' || !root.getElementsByTagNameNS('*', 'file').length) {
            throw new Error('Der Suchdienst hat keine gültige NZB-Datei geliefert.');
        }
        return text.replace(/^(\uFEFF?<\?xml\s[^?]*?\bencoding\s*=\s*)(['"])[^'"]*\2/i, '$1$2UTF-8$2');
    };
    return handleNzb(null, nzb_info.t, nzb_info.p, fetchNZB);
}

function loadNzbLnk(nzblnk) {
    let nzb_info = parseNzblnkUrl(nzblnk)

    infoModal.resetModal()
    infoModal.showModal()

    const loadFunctions = [
        {
            info: "NzbIndex",
            func: loadFromNzbIndex,
        },
        {
            info: "NzbKing",
            func: loadFromNzbKing,
        },
        {
            info: "BinSearch",
            func: loadFromBinSearch,
        }
    ]

    for (const indexer of additionalIndexers) {
        const apiKey = String(SETTINGS[indexer.key] || '').trim();
        if (apiKey) loadFunctions.push({
            info: indexer.info,
            func: (info, when_failed) => loadFromNewznab(indexer, apiKey, info, when_failed)
        });
    }

    let load = function () {
        infoModal.print(`Keine Nzb gefunden :( `)
        setTimeout(() => {
            infoModal.closeModal()
        }, 6000)
    };

    Array.from(loadFunctions).reverse().forEach(function (f) {
        const old_load = load
        load = function () {
            infoModal.print(`Versuche ${f.info} ....`)

            return f.func(nzb_info, old_load)
        }
    })

    load()
}

// ------------------------------------------------------------
// settings menu command

// Register the settings menu command
if (GM.registerMenuCommand) {
    GM.registerMenuCommand("Einstellungen", () => {
        settingsModal.showModal();
    });
}

document.addEventListener('open-nzbload-settings', () => {
    settingsModal.showModal();
})

// ------------------------------------------------------------
// trigger

function checkHandelLink(url) {
    if (url.startsWith('nzblnk:')) {
        return true;
    }
    return false;
}

async function handleLink(url) {
    if (!await settingsReady) {
        alert('Einstellungen konnten nicht geladen werden. Bitte die Seite neu laden.');
        return;
    }
    loadNzbLnk(url);
}

// Event-Delegation für alle nzblnk-Links
document.body.addEventListener('click', (event) => {
    const linkElement = event.target.closest('a');
    const url = linkElement?.href;
    if (url && checkHandelLink(url)) {
        event.preventDefault();
        handleLink(url);
    }
});

console.log("finished loading nzb-load script", GM.info.script.version);

async function openNzbLoadSettings(showSab = false) {
    modal.closeModal();
    infoModal.closeModal();
    await settingsModal.showModal();
    if (showSab && settingsModal.dialog.open) settingsModal.showSabTab();
}

async function handleNzb(downloadLink, fileName, password, fetchNZB) {
    if (!await settingsReady) {
        infoModal.error('Einstellungen konnten nicht geladen werden. Bitte die Seite neu laden.');
        return;
    }
    const parameters = { downloadLink, fileName, password, fetchNZB };
    if (SETTINGS.ausgabe === 'download') {
        return downloadAndSave(parameters);
    }
    if (SETTINGS.ausgabe === 'sabnzbd' && SETTINGS.sab_url.trim() && SETTINGS.sab_api_key.trim()) {
        return SABNZBD.send({...parameters, category: SETTINGS.sab_default_category || '*'});
    }
    const saveButton = getDownloadButton(parameters);
    const settingsButton = {
        name: 'SABnzbd-Einstellungen',
        bgColor: '#555',
        f: () => openNzbLoadSettings(true)
    };
    if (!SETTINGS.sab_url.trim() || !SETTINGS.sab_api_key.trim()) {
        return openMenu([saveButton, settingsButton]);
    }
    SABNZBD.getCategories({
        callback: function (categories) {
            const buttons = refreshSabCategories(categories).map(category =>
                SABNZBD.makeButton(parameters, category)
            );
            openMenu([...buttons, saveButton, settingsButton]);
        },
        failed_callback: function (error) {
            openMenu([saveButton, settingsButton]);
            alert(error.message);
        }
    });
}
