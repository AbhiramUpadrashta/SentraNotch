// Sentra Notch website — interactive notch demos (pure JS/CSS, no libraries).
(function(){
  const $=s=>document.querySelector(s);
  const clock=()=>{const t=new Date().toLocaleTimeString([], {hour:'numeric',minute:'2-digit'});['clock','clock2'].forEach(id=>{const e=document.getElementById(id);if(e)e.textContent=t})};clock();setInterval(clock,15000);


  const I={
    vol:'<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5 6 9H3v6h3l5 4z" fill="#fff"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/><path d="M18.5 5.5a9 9 0 0 1 0 13"/></svg>',
    mute:'<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 5 6 9H3v6h3l5 4z" fill="#fff"/><path d="m16 9 5 6M21 9l-5 6"/></svg>',
    sun:'<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4" fill="#fff"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>',
    mouse:'<svg viewBox="0 0 24 24" width="16" height="16" fill="#fff"><rect x="6" y="2.5" width="12" height="19" rx="6"/><rect x="11.2" y="5.5" width="1.6" height="4" rx=".8" fill="#000"/></svg>',
    pods:'<svg viewBox="0 0 24 24" width="17" height="17" fill="#fff"><path d="M6.5 3a3.5 3.5 0 0 0-1 6.85V19a1.5 1.5 0 0 0 3 0V6.5A3.5 3.5 0 0 0 6.5 3zM17.5 3a3.5 3.5 0 0 1 1 6.85V19a1.5 1.5 0 0 1-3 0V6.5A3.5 3.5 0 0 1 17.5 3z"/></svg>',
    bolt:'<svg viewBox="0 0 24 24" width="13" height="13" fill="#4ade80"><path d="M13 2 4 14h6l-1 8 9-12h-6z"/></svg>',
    batt:(l,c)=>`<svg viewBox="0 0 28 14" width="26" height="13"><rect x=".75" y=".75" width="23" height="12.5" rx="3.5" fill="none" stroke="rgba(255,255,255,.5)" stroke-width="1.5"/><rect x="2.5" y="2.5" width="${19.5*l/100}" height="9" rx="2" fill="${c}"/><rect x="25" y="4.5" width="2" height="5" rx="1" fill="rgba(255,255,255,.5)"/></svg>`,
    radio:'<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="#7c9cff" stroke-width="2" stroke-linecap="round"><path d="M8 8a6 6 0 0 0 0 8M5 5a10 10 0 0 0 0 14M16 8a6 6 0 0 1 0 8M19 5a10 10 0 0 1 0 14"/><circle cx="12" cy="12" r="1.6" fill="#7c9cff"/></svg>',
    home:'<svg viewBox="0 0 24 24" width="13" height="13" fill="#fff"><path d="M12 3 2.5 11h2.5v9h5v-6h4v6h5v-9h2.5z"/></svg>',
    tray:'<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="rgba(255,255,255,.55)" stroke-width="2"><path d="M3 13h5l1.5 3h5L16 13h5v6H3zM5 13l2-8h10l2 8"/></svg>',
    gear:'<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="rgba(255,255,255,.7)" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9 7 7M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1"/></svg>',
    shuf:'<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="#ff8fb1" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h3c4 0 6 12 10 12h5M3 18h3c1.6 0 2.8-1.6 3.8-3.6M21 6h-5c-1.6 0-2.8 1.6-3.8 3.6M18 3l3 3-3 3M18 15l3 3-3 3"/></svg>',
    prev:'<svg viewBox="0 0 24 24" width="17" height="17" fill="#fff"><path d="M11 6v12L2.5 12zM21 6v12l-8.5-6z"/></svg>',
    next:'<svg viewBox="0 0 24 24" width="17" height="17" fill="#fff"><path d="M13 6v12l8.5-6zM3 6v12l8.5-6z"/></svg>',
    pause:'<svg viewBox="0 0 24 24" width="22" height="22" fill="#fff"><rect x="6" y="4.5" width="4" height="15" rx="1.2"/><rect x="14" y="4.5" width="4" height="15" rx="1.2"/></svg>',
    bell:'<svg viewBox="0 0 24 24" width="15" height="15" fill="#7c9cff"><path d="M12 2a6 6 0 0 0-6 6v4l-2 3h16l-2-3V8a6 6 0 0 0-6-6zM9.5 19a2.5 2.5 0 0 0 5 0z"/></svg>',
    alarm:'<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="#ffb34d" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="13" r="7.5"/><path d="M12 9.5V13l2.5 2M4 4.5 6.5 2.5M20 4.5l-2.5-2"/></svg>',
    rep:'<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="rgba(255,255,255,.75)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4"/></svg>',
  };
  const wavesSVG=(c='#ff8fb1')=>`<canvas class="waves" data-c="${c}" width="52" height="32"></canvas>`;
  const ring=(lv,charging)=>{const c=lv<=20?'#ff5a5a':lv<=40?'#ffb34d':'#4ade80',r=9,cf=2*Math.PI*r;
    return `<svg class="ring" viewBox="0 0 22 22"><circle cx="11" cy="11" r="${r}" fill="none" stroke="rgba(255,255,255,.18)" stroke-width="2.4"/><circle cx="11" cy="11" r="${r}" fill="none" stroke="${c}" stroke-width="2.4" stroke-linecap="round" stroke-dasharray="${cf}" stroke-dashoffset="${cf*(1-lv/100)}" transform="rotate(-90 11 11)" style="transition:stroke-dashoffset 1s"/>${charging?`<text x="11" y="14.5" text-anchor="middle" font-size="9" fill="${c}">⚡</text>`:`<text x="11" y="14" text-anchor="middle" font-size="7.5" font-weight="700" fill="#fff">${lv}</text>`}</svg>`};
  const icons={mouse:'🖱',airpods:'🎧',keyboard:'⌨️'};

  const states={
    music:{w:272,h:32,html:`<div class="n-row"><div class="n-art"></div>${wavesSVG()}</div>`,cap:'Music · waves'},
    peek:{w:300,h:66,html:`<div class="n-row"><div class="n-art"></div>${wavesSVG()}</div><div class="n-bottom">Neon Skies<span class="n-sub">Aurora Lane</span></div>`,cap:'Sneak peek · new song'},
    volume:{w:240,h:62,html:`<div class="n-row">${I.vol}<b style="font-size:12px" id="hv">62</b></div><div class="n-bottom" style="padding:0 18px"><div class="bar"><i id="hb" style="width:62%"></i></div></div>`,cap:'Volume HUD',run:hud},
    brightness:{w:240,h:62,html:`<div class="n-row">${I.sun}<b style="font-size:12px" id="hv">40</b></div><div class="n-bottom" style="padding:0 18px"><div class="bar"><i id="hb" style="width:40%"></i></div></div>`,cap:'Brightness HUD',run:hud},
    mute:{w:240,h:62,html:`<div class="n-row">${I.mute}<b style="font-size:12px">0</b></div><div class="n-bottom" style="padding:0 18px"><div class="bar"><i style="width:0"></i></div></div>`,cap:'Muted'},
    pair:{w:440,h:58,html:`<div class="n-row"><span class="spin" style="display:inline-flex">${I.mouse}</span><span id="pr" style="display:inline-flex">${I.radio}</span></div><div class="n-bottom">Magic Mouse<span class="n-sub" id="ps">Connecting…</span></div>`,cap:'NEW · Bluetooth pairing',run:pair},
    airpods:{w:440,h:58,html:`<div class="n-row"><span class="spin" style="display:inline-flex">${I.pods}</span><span id="pr" style="display:inline-flex">${I.radio}</span></div><div class="n-bottom">AirPods Pro<span class="n-sub" id="ps">Connecting…</span></div>`,cap:'NEW · AirPods battery',run:el=>pair(el,true)},
    notif:{w:480,h:74,html:`<div class="n-row"><span class="wig" style="display:inline-flex">${I.bell}</span><span style="font-size:11px;color:#99a">Now</span></div><div class="n-bottom" style="line-height:1.35">Sam<br><span class="n-sub" style="margin:0">Running 5 min late, order me a latte ☕</span></div>`,cap:'NEW · Notifications'},
    alarm:{w:480,h:74,html:`<div class="n-row"><span class="wig" style="display:inline-flex">${I.alarm}</span><span style="font-size:11px;color:#ffb34d">Alarm</span></div><div class="n-bottom" style="line-height:1.35">Wake up<br><span class="n-sub" style="margin:0">7:00 AM · Clock</span></div>`,cap:'NEW · Alarms'},
    charging:{w:350,h:32,html:`<div class="n-row"><b style="color:#4ade80;font-size:12px">Charging</b><span style="font-size:12px;display:inline-flex;gap:6px;align-items:center">78% ${I.batt(78,"#4ade80")}${I.bolt}</span></div>`,cap:'Charging'},
    open:{w:640,h:200,open:true,html:`<div class="n-row" style="opacity:.8;font-size:12px"><span style="display:inline-flex;gap:12px;align-items:center">${I.home}${I.tray}</span><span style="display:inline-flex;gap:8px;align-items:center">${I.gear}84% ${I.batt(84,"#4ade80")}</span></div><div class="n-open"><div class="big-art"></div><div class="pl" style="flex:1"><h4>Neon Skies</h4><p>Aurora Lane · Night Drive</p><div class="scr"><i></i></div><div class="ctl">${I.shuf}${I.prev}${I.pause}${I.next}${I.rep}</div></div><div class="cal"><b>Today</b><div class="ev"><i style="background:#7c9cff"></i><div>Design review<small>10:00 – 10:30</small></div></div><div class="ev"><i style="background:#ff8fb1"></i><div>Lunch with Sam<small>13:00</small></div></div><div class="ev"><i style="background:#5fd9b6"></i><div>Ship Sentra<small>Reminder</small></div></div></div></div>`,cap:'Open notch · hover'},
  };
  function hud(el){let v=parseInt(el.querySelector('#hv').textContent),d=1;const b=el.querySelector('#hb'),t=el.querySelector('#hv');let n=0;const iv=setInterval(()=>{v=Math.max(0,Math.min(100,v+d*6.25));if(++n%5==0)d=-d;b.style.width=v+'%';t.textContent=Math.round(v)},260);return()=>clearInterval(iv)}
  function pair(el,pods){const to=setTimeout(()=>{el.querySelector('#pr').innerHTML=ring(pods?92:64,!pods);el.querySelector('#ps').textContent=pods?'L 92%  R 94%  Case 71%':'64% · Charging'},2000);return()=>clearTimeout(to)}

  function render(el,name){const s=states[name];if(el._stop)el._stop();el.style.width=s.w+'px';el.style.height=s.h+'px';el.classList.toggle('open',!!s.open);el.classList.remove('show');
    el.innerHTML=s.html;requestAnimationFrame(()=>el.classList.add('show'));el._stop=s.run?s.run(el):null;}

  // canvas waves (same maths as the app)
  function drawWaves(){document.querySelectorAll('canvas.waves').forEach(c=>{const x=c.getContext('2d'),w=c.width,h=c.height,t=performance.now()/1000;x.clearRect(0,0,w,h);
    for(let l=0;l<3;l++){x.beginPath();const amp=h/2*(.85-l*.22)*(.6+.4*Math.abs(Math.sin(t*1.7+l)));for(let i=0;i<=w;i++){const r=i/w,y=h/2+amp*Math.sin(r*Math.PI)*Math.sin(r*Math.PI*(2.5+l)-t*(4+l*1.3));i?x.lineTo(i,y):x.moveTo(i,y)}
    x.strokeStyle=c.dataset.c;x.globalAlpha=1-l*.3;x.lineWidth=3.4-l*.8;x.stroke()}x.globalAlpha=1});requestAnimationFrame(drawWaves)}
  requestAnimationFrame(drawWaves);

  // hero cycle
  const notch=$('#notch'),cap=$('#cap'),tabs=$('#tabs');
  const order=['music','peek','volume','pair','notif','brightness','charging','airpods','alarm','mute','open'];
  const labels={music:'Music',peek:'Sneak peek',volume:'Volume',pair:'Mouse pairing',brightness:'Brightness',charging:'Charging',airpods:'AirPods',notif:'Notification',alarm:'Alarm',mute:'Mute',open:'Open notch'};
  let i=0,timer,manual=false;
  order.forEach(n=>{const b=document.createElement('button');b.textContent=labels[n];b.onclick=()=>{manual=true;go(order.indexOf(n));clearInterval(timer);timer=setInterval(next,4200)};tabs.appendChild(b)});
  function go(k){i=k;render(notch,order[i]);cap.textContent=states[order[i]].cap;[...tabs.children].forEach((b,j)=>b.classList.toggle('on',j==i))}
  function next(){go((i+1)%order.length)}
  go(0);timer=setInterval(next,3200);
  notch.addEventListener('mouseenter',()=>{clearInterval(timer);go(order.indexOf('open'))});
  notch.addEventListener('mouseleave',()=>{timer=setInterval(next,3200)});

  // pairing spotlight loop
  const pn=$('#pairNotch');if(pn){let k=0;const seq=['pair','airpods'];const loop=()=>{render(pn,seq[k++%2])};loop();setInterval(loop,4500)}

  // feature cards with live mini notches
  const feats=[
    ['music','Music from any app','Apple Music, Spotify, YouTube in your browser — album art, flowing waves, controls, scrubbing and synced lyrics.'],
    ['volume','Volume & brightness','Smooth HUDs for volume, mute, display and keyboard light. Optionally replaces Apple\'s pop-up.'],
    ['pair','Bluetooth pairing','NEW: devices spin in for 2 seconds, then show their battery. Mice, keyboards, AirPods, headphones.',1],
    ['notif','Notifications & alarms','NEW: messages, mail, calendar and Clock alarms ring in the notch with the title and first line.',1],
    ['charging','Battery & charging','Plugged in, unplugged, fully charged and low-battery warnings — at a glance.'],
    ['peek','Sneak peek','A new song slides out for 2–3 seconds, then the notch tucks itself back in.'],
    ['open','Calendar, shelf & mirror','Today\'s agenda and reminders, a drag-and-drop shelf with AirDrop, and a camera mirror.'],
  ];
  const fg=$('#feat');feats.forEach(([st,t,p,isNew])=>{const c=document.createElement('div');c.className='card reveal';
    c.innerHTML=`${isNew?'<span class="new">NEW</span>':''}<div class="mini"><div class="notch" style="left:50%"></div></div><h3>${t}</h3><p>${p}</p>`;fg.appendChild(c);
    const n=c.querySelector('.notch');const s=st==='open'?'peek':st;render(n,s);
    c.addEventListener('mouseenter',()=>{if(st==='pair'||st==='volume')render(n,s)})});

  // themes clickable
  document.querySelectorAll('.th').forEach(t=>t.onclick=()=>{document.querySelectorAll('.th').forEach(x=>x.classList.remove('on'));t.classList.add('on')});

  // version from GitHub
  fetch('https://api.github.com/repos/AbhiramUpadrashta/SentraNotch/releases/latest').then(r=>r.ok?r.json():null).then(j=>{if(j&&j.tag_name)$('#ver').textContent=j.tag_name+' · Free · macOS 14 Sonoma or later · Apple Silicon & Intel · MIT licensed'}).catch(()=>{});

  // reveal
  const io=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting){e.target.classList.add('in');io.unobserve(e.target)}}),{threshold:.12});
  document.querySelectorAll('.reveal').forEach(e=>io.observe(e));
})();
