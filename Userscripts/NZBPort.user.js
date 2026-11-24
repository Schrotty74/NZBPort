// ==UserScript==
// @name         NZBPort
// @namespace    https://github.com/Schrotty74/NZBPort
// @version      0.1.1
// @description  Resolve NZBlnk links and NewzBay downloads; save NZBs or submit them to SABnzbd.
// @author       Schrotty74
// @match        http://*/*
// @match        https://*/*
// @run-at       document-idle
// @inject-into  content
// @grant        GM.getValue
// @grant        GM.setValue
// @grant        GM.registerMenuCommand
// @grant        GM.xmlHttpRequest
// @grant        GM_xmlhttpRequest
// @connect      *
// ==/UserScript==
(() => {
  'use strict';
  const providers = [
    ['Treasure Maps','treasure_maps_api_key','treasure-maps.com'],
    ['NewzBay','newzbay_api_key','newzbay.cc'],
    ['NinjaCentral','ninjacentral_api_key','ninjacentral.co.za'],
    ['DrunkenSlug','drunkenslug_api_key','drunkenslug.com'],
    ['NZBFinder','nzbfinder_api_key','nzbfinder.ws'],
    ['Videothek.io','videothek_api_key','videothek.io']
  ];
  const defaults = {ausgabe:'sab_menu',sab_url:'http://localhost:8080/api',sab_api_key:'',sab_default_category:'*',sab_sub_menu:true,sab_categories:[],sab_hidden_categories:[]};
  for (const [,key] of providers) defaults[key]='';
  const storage = 'NZBPort.preferences';
  let config = structuredClone(defaults), active = false;
  const clean = input => {
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw Error('Ungültige Einstellungsdatei');
    const out = structuredClone(defaults);
    for (const key of Object.keys(defaults)) if (typeof defaults[key]==='string' && typeof input[key]==='string') out[key]=input[key].trim();
    if (!['sab_menu','sabnzbd','download'].includes(out.ausgabe)) out.ausgabe='sab_menu';
    if (typeof input.sab_sub_menu==='boolean') out.sab_sub_menu=input.sab_sub_menu;
    if (Array.isArray(input.sab_hidden_categories)) out.sab_hidden_categories=input.sab_hidden_categories.filter(x=>typeof x==='string');
    if (Array.isArray(input.sab_categories)) out.sab_categories=input.sab_categories.flatMap(x=>typeof x==='string'?[{value:x,fav:false}]:typeof x?.value==='string'?[{value:x.value,fav:x.fav===true}]:[]);
    return out;
  };
  const ready = (async()=>{config=clean(await GM.getValue(storage,defaults));})();
  const persist = async value => {const next=clean(value); await GM.setValue(storage,next); const check=await GM.getValue(storage); if(JSON.stringify(clean(check))!==JSON.stringify(next)) throw Error('Speichern nicht bestätigt'); config=next;};
  function address(base, params={}) {const u=new URL(base); for(const [k,v] of Object.entries(params)) u.searchParams.set(k,String(v)); return u;}
  function safeURL(raw, origin) {try {const u=new URL(raw); return u.protocol==='https:'&&!u.username&&!u.password&&!u.hash&&(!origin||u.origin===origin)?u:null;}catch{return null;}}
  function request(url, options={}) {
    return new Promise((resolve,reject)=>{
      const target=new URL(url); const fail=()=>reject(Error(`Netzwerkfehler bei ${target.hostname}`));
      const receive=r=>{if(r.status<200||r.status>=300){let detail='HTTP '+r.status;if(r.status===429)detail+=' – API-Limit erreicht';if(r.status===401||r.status===403)detail+=' – API-Key oder Kontoberechtigung prüfen';if(target.hostname==='nzbfinder.ws'&&r.status===401&&/<error\b[^>]*\bcode=["']102["']/i.test(String(r.responseText||'').slice(0,65536)))detail+=' – Premium-Mitgliedschaft erforderlich';reject(Error(target.hostname+': '+detail));return;} const final=r.finalUrl||r.responseURL; if(final){try{const dest=new URL(final,target);if(dest.origin!==target.origin || dest.username || dest.password){reject(Error('Unerwartete Weiterleitung'));return;}if(options.allowSlugDownload && dest.pathname!==target.pathname){if(dest.pathname!=='/getnzb'||dest.hash||!['i','r'].every(k=>dest.searchParams.getAll(k).length===1&&dest.searchParams.get(k))){reject(Error('Ungültige DrunkenSlug-Weiterleitung'));return;}}}catch{return fail();}} resolve(String(r.responseText??r.response??''));};
      const headers={...options.headers};
      if(target.origin==='https://videothek.io' && target.pathname==='/api' && (options.method||'GET')==='GET') headers['User-Agent']='NZBPort/nzb-load/0.1.1 (NZB link search; iOS Userscripts)';
      const args={method:options.method||'GET',url:target.href,headers,data:options.body,timeout:30000,responseType:'text',onload:receive,onerror:fail,ontimeout:()=>reject(Error(`Zeitüberschreitung bei ${target.hostname}`)),onabort:fail};
      try {const fn=typeof GM_xmlhttpRequest==='function'?GM_xmlhttpRequest:GM.xmlHttpRequest?.bind(GM)||GM.xmlhttpRequest?.bind(GM); if(!fn)throw Error();const result=fn(args); if(result?.then)result.then(receive,fail);} catch {fail();}
    });
  }
  function xml(text, limit=2097152){if(text.length>limit||/<!ENTITY\b/i.test(text))throw Error('Ungültige XML-Antwort');const doc=new DOMParser().parseFromString(text,'application/xml');if(doc.querySelector('parsererror'))throw Error('Ungültiges XML');return doc;}
  function nzb(text){const root=xml(text,16777216).documentElement;if(root.localName!=='nzb'||!root.getElementsByTagNameNS('*','file').length)throw Error('Keine gültige NZB-Datei');return text.replace(/(<\?xml[^?]*encoding\s*=\s*)["'][^"']+["']/i,'$1"UTF-8"');}
  function parseLink(raw){if(!/^nzblnk:\?/i.test(raw))throw Error('Ungültiger NZBlnk-Link');const p=new URLSearchParams(raw.slice(raw.indexOf('?')+1));const h=p.get('h')?.trim();if(!h)throw Error('Suchkennung fehlt');return {header:h,title:p.get('t')||'',password:p.get('p')||''};}
  const normalize=s=>s.toLowerCase().replace(/[._\s]+/g,' ').trim();
  async function publicSearch(which, link){
    if(which==='NZBIndex'){
      const result=JSON.parse(await request(address('https://nzbindex.com/api/search',{q:link.header,max:5,sort:'agedesc'})));
      const ids=[...new Set((result.data?.content||[]).map(x=>String(x.id??'')).filter(x=>/^[\w-]+$/.test(x)))];
      return ids.length?address('https://nzbindex.com/download',{ids:ids.join(',')}):null;
    }
    const king=which==='NZBKing', base=king?'https://www.nzbking.com':'https://www.binsearch.info';
    const doc=new DOMParser().parseFromString(await request(address(base+(king?'/':'/search'),king?{q:link.header}:{q:link.header,max:5})),'text/html');
    if(king){const ref=doc.querySelector('a[href^="/nzb:"]')?.getAttribute('href');return ref?safeURL(new URL(ref,base),base):null;}
    const id=doc.querySelector('form[action*="nzb"] input[type="checkbox"]')?.getAttribute('name');return id?address(base+'/nzb',{[id]:'on'}):null;
  }
  function releaseURL(item, host, key){
    const origin='https://'+host;
    if(host==='treasure-maps.com'){
      for(const el of item.querySelectorAll('enclosure')){const u=safeURL(el.getAttribute('url'),'https://file.treasure-maps.com');if(u&&/^\/getnzb\/[a-f0-9]{32}$/i.test(u.pathname)&&u.searchParams.get('r')&&[...u.searchParams].length===1)return u;}return null;
    }
    const attrs=[...item.getElementsByTagNameNS('*','attr')];const guid=item.querySelector('guid');
    const candidates=[...attrs.filter(a=>['guid','details','detailsurl','detailsUrl'].includes(a.getAttribute('name'))).map(a=>a.getAttribute('value')),guid?.textContent,guid?.getAttribute('id'),item.getAttribute('guid'),item.querySelector('link')?.textContent,item.querySelector('enclosure')?.getAttribute('url')];
    const pattern=host==='nzbfinder.ws'||host==='videothek.io'?/^(?:[a-f0-9]{32}|[a-f0-9]{40}|[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12})$/i:host==='drunkenslug.com'?/^(?:[a-f0-9]{32}|[a-f0-9]{40})$/i:/^[a-f0-9]{32}$/i;
    for(const raw of candidates){if(!raw)continue;let id=raw.trim();if(!pattern.test(id)){const u=safeURL(id,origin);if(!u)continue;id=u.pathname==='/api'?u.searchParams.get('id'):u.pathname.match(/^\/details\/([^/]+)\/?$/)?.[1];}if(id&&pattern.test(id))return address(origin+'/api',{t:'get',id,apikey:key,...(host==='videothek.io'?{o:'xml'}:{})});}return null;
  }
  async function privateSearch(provider,link){const [name,field,host]=provider;const key=config[field];if(!key||!link.title)return null;const url=address('https://'+host+'/api',{t:'search',q:link.title,apikey:key,o:'xml'});const doc=xml(await request(url,{headers:{Accept:'application/rss+xml, application/xml, text/xml','User-Agent':'NZBPort/0.1.1'}}));if(doc.documentElement.localName==='error'){const code=doc.documentElement.getAttribute('code')||'unbekannt';throw Error(name+': API-Fehler '+code+(host==='videothek.io'?' – Premium und Tool-Freigabe prüfen':host==='nzbfinder.ws'&&code==='102'?' – Premium-Mitgliedschaft erforderlich':' – API-Key und Kontoberechtigung prüfen'));}const matches=[...doc.querySelectorAll('channel > item')].filter(i=>normalize(i.querySelector('title')?.textContent||'')===normalize(link.title));if(matches.length>1)throw Error('Mehrdeutiger Releasetitel');return matches.length?releaseURL(matches[0],host,key):null;}
  function endpoint(settings=config){const u=new URL(settings.sab_url);if(!['http:','https:'].includes(u.protocol)||u.username||u.password||u.hash||!settings.sab_api_key)throw Error('SABnzbd-Adresse oder API-Key fehlt');return u;}
  async function categories(settings){const data=JSON.parse(await request(address(endpoint(settings),{mode:'get_cats',output:'json',apikey:settings.sab_api_key})));if(!Array.isArray(data.categories))throw Error('Keine Kategorien erhalten');const old=new Map(settings.sab_categories.map(c=>[c.value.toLowerCase(),c.fav]));const hidden=new Set(settings.sab_hidden_categories.map(c=>c.toLowerCase()));return [...new Set(data.categories.filter(x=>typeof x==='string'))].filter(x=>!hidden.has(x.toLowerCase())).map(value=>({value,fav:old.get(value.toLowerCase())===true}));}
  const filename=link=>((link.title||link.header).replace(/\.nzb$/i,'')+(link.password?'{{'+link.password+'}}':'')).replace(/[\\/\x00-\x1f\x7f"]/g,'_').replace(/\.nzb$/i,'')+'.nzb';
  function saveFile(content,name,type){const url=URL.createObjectURL(new Blob([content],{type}));const a=document.createElement('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),60000);}
  async function submit(found,link,cat){const fields={mode:found.private?'addfile':'addurl',output:'json',apikey:config.sab_api_key,cat,nzbname:link.title||link.header};if(link.password)fields.password=link.password;let body,contentType;
    if(found.private){const payload=await obtainNZB(found);const boundary='NZBPort'+Array.from(crypto.getRandomValues(new Uint8Array(16)),x=>x.toString(16).padStart(2,'0')).join('');const parts=[];for(const [key,value] of Object.entries(fields))parts.push(`--${boundary}\r\nContent-Disposition: form-data; name="${key}"\r\n\r\n${value}\r\n`);parts.push(`--${boundary}\r\nContent-Disposition: form-data; name="name"; filename="${filename(link)}"\r\nContent-Type: application/x-nzb\r\n\r\n${payload}\r\n--${boundary}--\r\n`);body=parts.join('');contentType='multipart/form-data; boundary='+boundary;}
    else{body=new URLSearchParams({...fields,name:found.url.href}).toString();contentType='application/x-www-form-urlencoded';}
    const result=JSON.parse(await request(endpoint(),{method:'POST',body,headers:{'Content-Type':contentType,Accept:'application/json'}}));if(result.status!==true)throw Error('SABnzbd hat den Auftrag nicht bestätigt');
  }
  let panel;
  function element(tag,text,attrs={}){
    const node=document.createElement(tag);
    if(text!=null)node.textContent=text;
    for(const [k,v] of Object.entries(attrs)){
      if(k==='className') node.className=v;
      else if(k==='dataset' && v && typeof v==='object') Object.assign(node.dataset,v);
      else node[k]=v;
    }
    return node;
  }
  function close(){panel?.remove();panel=null;}
  function dialog(title){
    close();
    panel=element('div');
    const shadow=panel.attachShadow({mode:'closed'});
    const css=element('style',`
      :host{all:initial;position:fixed;inset:0;z-index:2147483647;font:16px -apple-system,BlinkMacSystemFont,"SF Pro Text",Arial,sans-serif;color-scheme:dark}
      .shade{position:absolute;inset:0;background:rgba(3,7,18,.62);backdrop-filter:blur(6px);display:grid;place-items:center;padding:14px;box-sizing:border-box}
      .modal{width:min(440px,100%);max-height:88vh;max-height:88dvh;overflow:auto;box-sizing:border-box;padding:18px;border-radius:20px;background:linear-gradient(180deg,rgba(14,18,28,.98),rgba(8,11,18,.98));color:#eef3ff;border:1px solid rgba(140,170,255,.18);box-shadow:0 25px 60px rgba(0,0,0,.45),inset 0 1px 0 rgba(255,255,255,.04)}
      .header{display:flex;align-items:center;gap:10px;margin-bottom:14px}
      h2{font-size:19px;line-height:1.2;margin:0;font-weight:700;letter-spacing:-.02em}
      h3{font-size:15px;line-height:1.3;margin:16px 0 8px;color:#dbe6ff}
      p{margin:8px 0;color:#dce5ff;overflow-wrap:anywhere}
      .muted{opacity:.76;font-size:13px}
      .stack{display:grid;gap:10px}
      .row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
      .row span{flex:1;min-width:0;overflow-wrap:anywhere}
      .tabs{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
      label{display:grid;gap:6px;margin:0 0 10px;color:#e6eeff;font-weight:600;font-size:14px}
      .checkbox-line{display:flex;align-items:center;gap:10px;margin:4px 0 12px;color:#e6eeff;font-weight:600}
      .checkbox-line input{width:18px;height:18px;accent-color:#77a7ff}
      input:not([type=checkbox]),select{width:100%;box-sizing:border-box;min-height:44px;padding:11px 12px;border-radius:11px;border:1px solid rgba(149,168,208,.22);background:rgba(255,255,255,.045);color:#f3f7ff;outline:none;box-shadow:inset 0 1px 0 rgba(255,255,255,.03)}
      input:not([type=checkbox]):focus,select:focus{border-color:rgba(104,149,255,.75);box-shadow:0 0 0 3px rgba(95,143,255,.18)}
      select{appearance:auto}
      button{appearance:none;border:1px solid rgba(149,168,208,.2);border-radius:11px;min-height:42px;padding:10px 13px;font:inherit;font-weight:600;cursor:pointer;background:rgba(255,255,255,.05);color:#f0f5ff;transition:background .15s ease,border-color .15s ease,transform .08s ease,box-shadow .15s ease}
      button:hover{background:rgba(255,255,255,.09);border-color:rgba(149,168,208,.34)}
      button:active{transform:translateY(1px)}
      button:disabled{opacity:.55;cursor:default;transform:none}
      .btn-primary{background:linear-gradient(180deg,#78a7ff,#5e89ff);border-color:rgba(132,176,255,.65);color:#08101f;box-shadow:0 8px 20px rgba(79,131,255,.28)}
      .btn-primary:hover{background:linear-gradient(180deg,#85b0ff,#6a93ff)}
      .btn-secondary{background:rgba(255,255,255,.045)}
      .btn-icon{width:42px;min-width:42px;padding:0;font-size:20px;line-height:1;background:rgba(255,255,255,.04)}
      .btn-tab{min-height:40px;padding:9px 14px;background:rgba(255,255,255,.03)}
      .btn-tab.active{background:linear-gradient(180deg,#bcd4ff,#a6c2ff);color:#091122;border-color:rgba(190,214,255,.85);box-shadow:0 6px 18px rgba(136,176,255,.22)}
      .btn-star{width:42px;min-width:42px;padding:0;font-size:18px}
      .btn-danger{background:rgba(255,255,255,.02)}
      .btn-ghost{background:transparent}
      .section-card{padding:10px 0 2px}
      .category-row{display:flex;align-items:center;gap:8px;margin:7px 0;padding:2px 0}
      .category-row .name{flex:1;min-width:0;overflow-wrap:anywhere}
      .status{min-height:1.4em;margin:2px 2px 0;color:#aecaFF;font-size:13px}
      .footer{display:grid;gap:8px;margin-top:4px}

      .modal{background:linear-gradient(155deg,#23334b 0%,#18263b 36%,#141e2e 100%);border-color:#496381}
      .header{border-bottom:1px solid #45617d;padding-bottom:12px}
      h2{color:#b9ddff} h3{color:#9acff9}
      input:not([type=checkbox]),select{background:#101d30;border-color:#46617e}
      .btn-secondary{background:#293e59;border-color:#486581;color:#e3efff}
      .btn-tab{background:#293d58;border-color:#4b6583;color:#c7dfff}
      .btn-tab.active{background:linear-gradient(135deg,#367fda,#4264b8);color:white;border-color:#77aaff}
      .btn-category{background:linear-gradient(110deg,#254e72,#263e60);border-color:#487da8;color:#e7f5ff}
      .btn-category:hover{background:#386b96}
      .btn-favorite{background:#544425;border-color:#a78948;color:#ffe3a0}
      .btn-save{background:linear-gradient(110deg,#17665e,#20534d);border-color:#419e8e;color:#d9fff3}
      .btn-settings{background:linear-gradient(110deg,#f4ce51,#e6b72d);border-color:#ffe18a;color:#302400}
      .btn-star{color:#f6cf73;background:#443b2c;border-color:#8c7547}
      .btn-danger{background:#522e40;border-color:#94556b;color:#ffd0db}
      .btn-icon:not(.btn-danger){background:#32465f;border-color:#58718f}
      .status{color:#f5cf87}
      .category-row{background:#22344b;border-radius:10px;padding:5px 8px}
      .btn-primary{background:linear-gradient(120deg,#4389e7,#536ed0);color:#fff;border-color:#80b1ff}
      .btn-primary:hover{background:#467fd0}
    `);
    const shade=element('div',null,{className:'shade'});
    const box=element('section',null,{className:'modal'});
    box.setAttribute('role','dialog');
    box.setAttribute('aria-label',title);
    box.setAttribute('aria-modal','true');
    const head=element('div',null,{className:'header'});
    head.append(element('h2',title),element('span',null,{style:'flex:1'}),button('×',close,'btn-icon'));
    const content=element('div',null,{className:'stack'});
    box.append(head,content);
    shade.append(box);
    shadow.append(css,shade);
    document.documentElement.append(panel);
    shade.addEventListener('click',e=>{if(e.target===shade)close();});
    shadow.addEventListener('keydown',e=>{if(e.key==='Escape'){e.stopPropagation();close();}});
    return content;
  }
  function button(name,action,variant='btn-secondary'){
    const classes=['button'];
    if(variant) classes.push(...String(variant).split(/\s+/).filter(Boolean));
    const b=element('button',name,{type:'button',className:classes.join(' ')});
    b.addEventListener('click',async()=>{
      if(b.disabled)return;
      b.disabled=true;
      try{await action();}
      catch(e){alert(e.message||'Vorgang fehlgeschlagen');}
      finally{b.disabled=false;}
    });
    return b;
  }
  function say(container,message,kind='text'){
    container.append(element('p',message,{className:kind==='muted'?'muted':''}));
  }
  async function settings(tab='general'){
    await ready;
    let draft=structuredClone(config);
    const content=dialog('NZBPort – Einstellungen');
    const tabs=element('div',null,{className:'tabs'});
    const body=element('div',null,{className:'section-card'});
    const status=element('p',null,{className:'status'});
    const footer=element('div',null,{className:'footer'});
    content.append(tabs,body,status,footer);

    function input(labelText,key,type='text'){
      const field=element('input',null,{type,value:draft[key],autocomplete:'off',spellcheck:false});
      field.addEventListener('input',()=>draft[key]=field.value);
      const l=element('label',labelText);
      l.append(field);
      body.append(l);
    }
    function select(labelText,key,choices){
      const field=element('select');
      for(const [value,name] of choices)field.append(element('option',name,{value}));
      field.value=draft[key];
      field.addEventListener('change',()=>draft[key]=field.value);
      const l=element('label',labelText);
      l.append(field);
      body.append(l);
    }
    function renderTabs(){
      tabs.replaceChildren(
        createTab('general','Allgemein'),
        createTab('sab','SABnzbd'),
        createTab('transfer','Import / Export')
      );
    }
    function createTab(key,label){
      const b=button(label,()=>draw(key),`btn-tab ${tab===key?'active':''}`);
      return b;
    }
    function draw(next){
      tab=next;
      renderTabs();
      body.replaceChildren();
      status.textContent='';
      if(tab==='general'){
        select('Ausgabe','ausgabe',[['sab_menu','SABnzbd – Kategorie auswählen'],['sabnzbd','Direkt an SABnzbd'],['download','NZB-Datei speichern']]);
        for(const [name,key] of providers)input(name+' API-Key',key,'password');
      } else if(tab==='sab'){
        input('SABnzbd API-Adresse','sab_url','url');
        input('SABnzbd API-Key','sab_api_key','password');
        const choices=[['*','Standard'],...draft.sab_categories.filter(c=>c.value!=='*').map(c=>[c.value,c.value])];
        if(!choices.some(c=>c[0]===draft.sab_default_category))choices.push([draft.sab_default_category,draft.sab_default_category]);
        select('Standardkategorie','sab_default_category',choices);
        const line=element('label',null,{className:'checkbox-line'});
        const check=element('input',null,{type:'checkbox',checked:draft.sab_sub_menu});
        check.addEventListener('change',()=>draft.sab_sub_menu=check.checked);
        line.append(check,element('span','Kategorien-Untermenü (Kompatibilität)'));
        body.append(line);
        body.append(button('Kategorien von SABnzbd laden',async()=>{draft.sab_categories=await categories(draft);draw('sab');},'btn-secondary'));
        body.append(element('h3','Kategorien'));
        for(const c of draft.sab_categories){
          const row=element('div',null,{className:'category-row'});
          row.append(
            button(c.fav?'★':'☆',()=>{c.fav=!c.fav;draw('sab');},'btn-star'),
            element('span',c.value,{className:'name'}),
            button('×',()=>{if(confirm('Kategorie nur lokal ausblenden?')){draft.sab_hidden_categories.push(c.value);draft.sab_categories=draft.sab_categories.filter(x=>x!==c);draw('sab');}},'btn-icon btn-danger')
          );
          body.append(row);
        }
        if(draft.sab_hidden_categories.length) body.append(element('h3','Ausgeblendete Kategorien'));
        for(const c of draft.sab_hidden_categories){
          const row=element('div',null,{className:'category-row'});
          row.append(element('span',c,{className:'name'}),button('Einblenden',()=>{draft.sab_hidden_categories=draft.sab_hidden_categories.filter(x=>x!==c);draft.sab_categories.push({value:c,fav:false});draw('sab');},'btn-secondary'));
          body.append(row);
        }
      } else {
        say(body,'Die Einstellungsdatei enthält API-Schlüssel. Nur privat aufbewahren.','muted');
        body.append(button('Einstellungen exportieren',()=>saveFile(JSON.stringify(clean(draft),null,2),'NZBPort-settings.json','application/json'),'btn-secondary'));
        const fileWrap=element('label','Einstellungen importieren');
        const file=element('input',null,{type:'file',accept:'.json,application/json'});
        file.addEventListener('change',async()=>{
          try{
            if(!file.files[0])return;
            if(file.files[0].size>1048576)throw Error('Datei zu groß');
            draft=clean(JSON.parse(await file.files[0].text()));
            status.textContent='Importiert – zum Übernehmen speichern.';
            draw('transfer');
            status.textContent='Importiert – zum Übernehmen speichern.';
          }catch(e){status.textContent=e.message;}
        });
        fileWrap.append(file);
        body.append(fileWrap);
      }
    }

    footer.append(
      button('Speichern',async()=>{await persist(draft);status.textContent='Gespeichert.';},'btn-primary'),
      button('Schließen',close,'btn-secondary')
    );
    draw(tab);
  }
  async function obtainNZB(found){
    if(found.read) return found.read();
    const headers={Accept:'application/x-nzb, application/xml, text/xml'};
    if(found.url.hostname==='nzbfinder.ws') headers['User-Agent']='NZBPort/0.1.1 (NZB link search; iOS Userscripts)';
    return nzb(await request(found.url,{headers,allowSlugDownload:found.private&&found.url.hostname==='drunkenslug.com'}));
  }
  async function download(found,link){saveFile(await obtainNZB(found),filename(link),'application/x-nzb');}
  function choose(found,link){
    const content=dialog('NZBPort');
    say(content,link.title||link.header);
    const status=element('p','SABnzbd-Verbindung wird geprüft …',{className:'status'});
    const list=element('div',null,{className:'stack'});
    let sending=false;
    const send=async cat=>{
      if(sending)return;
      sending=true;
      for(const b of list.querySelectorAll('button'))b.disabled=true;
      try{await submit(found,link,cat);if(content.isConnected)close();}
      catch(e){if(!content.isConnected)return;const error=dialog('Übergabe fehlgeschlagen');say(error,e.message+'. Vor erneutem Senden die SABnzbd-Warteschlange prüfen.');error.append(button('NZB-Datei speichern',async()=>{await download(found,link);close();},'btn-save'),button('SABnzbd-Einstellungen',()=>settings('sab'),'btn-settings'));}
      finally{sending=false;}
    };
    function render(items){
      const hidden=new Set(config.sab_hidden_categories.map(x=>x.toLowerCase()));
      list.replaceChildren(...items.filter(c=>!hidden.has(c.value.toLowerCase())).map(c=>button((c.fav?'★ ':'')+c.value,()=>send(c.value),c.fav?'btn-category btn-favorite':'btn-category')));
    }
    render(config.sab_categories);
    content.append(status,list,button('NZB-Datei speichern',async()=>{await download(found,link);if(content.isConnected)close();},'btn-save'),button('SABnzbd-Einstellungen',()=>settings('sab'),'btn-settings'));
    const snapshot=structuredClone(config);
    let timer;
    void Promise.race([categories(snapshot),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Keine rechtzeitige Antwort')),5000);})]).then(items=>{
      if(!content.isConnected||sending)return;
      render(items);status.textContent='';
    }).catch(()=>{
      if(!content.isConnected||sending)return;
      status.textContent='SABnzbd antwortet nicht – gespeicherte Kategorien werden angezeigt.';
    }).finally(()=>clearTimeout(timer));
  }
  async function process(raw){if(active)return;active=true;try{await ready;const link=parseLink(raw);const progress=dialog('NZBPort – Suche');say(progress,link.title||link.header);let found;const jobs=[...['NZBIndex','NZBKing','BinSearch'].map(name=>({name,run:()=>publicSearch(name,link),private:false})),...providers.filter(p=>config[p[1]]).map(p=>({name:p[0],run:()=>privateSearch(p,link),private:true}))];for(const job of jobs){if(!panel)return;say(progress,'Suche bei '+job.name+' …');try{const url=await job.run();if(url){found={url,private:job.private};break;}}catch(e){say(progress,e.message);}}if(!panel)return;if(!found){say(progress,'Keine passende NZB gefunden.');return;}if(config.ausgabe==='download'){await download(found,link);close();}else if(config.ausgabe==='sabnzbd'&&config.sab_api_key&&config.sab_url){try{await submit(found,link,config.sab_default_category||'*');close();}catch(e){const err=dialog('Übergabe fehlgeschlagen');say(err,e.message+'. Vor erneutem Senden die Warteschlange prüfen.');err.append(button('NZB-Datei speichern',async()=>{await download(found,link);close();},'btn-save'),button('SABnzbd-Einstellungen',()=>settings('sab'),'btn-settings'));}}else await choose(found,link);}catch(e){say(dialog('NZBPort – Fehler'),e.message);}finally{active=false;}}
  // NewzBay website integration. The original download link is left intact.
  const newzBayOrigins = new Set(['https://newzbay.cc','https://www.newzbay.cc']);
  function pageNZB(anchor, pageOrigin){
    if(!newzBayOrigins.has(pageOrigin)) return null;
    const target=safeURL(anchor.href,pageOrigin);
    if(!target) return null;
    const segments=target.pathname.split('/').filter(Boolean);
    if(segments.length<2||segments.length>3||segments[0].toLowerCase()!=='getnzb'||!/^[0-9a-f]{32}$/i.test(segments[1])) return null;
    let title=segments[1];
    if(segments.length===3){
      try {title=decodeURIComponent(segments[2]).replace(/[\\/"\x00-\x1f\x7f]/g,'_').slice(0,240)||title;} catch {}
    }
    return {url:new URL(target.pathname,pageOrigin),title};
  }
  function pageSource(entry){
    let pending;
    return {url:entry.url,private:true,read(){
      if(!pending) pending=(async()=>{
        const response=await fetch(entry.url.href,{credentials:'same-origin',cache:'no-store',headers:{Accept:'application/x-nzb, application/xml, text/xml'}});
        const destination=safeURL(response.url,entry.url.origin);
        if(!response.ok||!destination||!/^\/getnzb(?:\/|$)/i.test(destination.pathname)) throw Error('NewzBay: NZB-Abruf fehlgeschlagen. Bitte Anmeldung prüfen.');
        return nzb(await response.text());
      })().catch(error=>{pending=undefined;throw error;});
      return pending;
    }};
  }
  function installNewzBayActions(){
    const controls=new Map();
    const sync=()=>{
      for(const [anchor,control] of controls){
        if(!anchor.isConnected||!pageNZB(anchor,location.origin)||control.previousElementSibling!==anchor){control.remove();controls.delete(anchor);}
      }
      for(const anchor of document.querySelectorAll('a[href*="/getnzb/"]')){
        if(controls.has(anchor)||!pageNZB(anchor,location.origin)) continue;
        const control=element('button',navigator.language.toLowerCase().startsWith('de')?'An SABnzbd senden':'Send to SABnzbd',{type:'button'});
        control.style.cssText='display:block;width:100%;padding:8px 12px;margin:4px 0;border:1px solid #d2ad39;border-radius:8px;background:#f4ce51;color:#302400;font:inherit;cursor:pointer;text-align:center';
        control.addEventListener('click',async event=>{
          event.preventDefault();event.stopPropagation();
          const entry=pageNZB(anchor,location.origin);
          if(!entry||active)return;
          active=true;
          try{await ready;choose(pageSource(entry),{header:entry.title,title:entry.title,password:''});}
          catch(error){say(dialog('NZBPort – Fehler'),error.message);}
          finally{active=false;}
        });
        anchor.insertAdjacentElement('afterend',control);
        controls.set(anchor,control);
      }
    };
    let scheduled=false;
    const observer=new MutationObserver(()=>{
      if(scheduled)return;
      scheduled=true;
      requestAnimationFrame(()=>{scheduled=false;sync();});
    });
    sync();
    observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['href']});
  }
  if(window.top===window&&newzBayOrigins.has(location.origin))installNewzBayActions();
  document.addEventListener('click',e=>{const anchor=e.target instanceof Element?e.target.closest('a[href]'):null;const href=anchor?.getAttribute('href');if(href&&/^nzblnk:/i.test(href)){e.preventDefault();e.stopPropagation();void process(href);}},true);
  if(typeof GM.registerMenuCommand==='function')GM.registerMenuCommand('NZBPort – Einstellungen',()=>settings().catch(e=>alert(e.message)));
  document.addEventListener('open-nzbport-settings',()=>settings().catch(e=>alert(e.message)));
})();
