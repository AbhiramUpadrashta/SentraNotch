// Sentra Notch website — interactive notch demos (pure JS/CSS, no libraries).
(function(){
  const $=s=>document.querySelector(s);
  const clock=()=>{const t=new Date().toLocaleTimeString([], {hour:'numeric',minute:'2-digit'});['clock','clock2'].forEach(id=>{const e=document.getElementById(id);if(e)e.textContent=t})};clock();setInterval(clock,15000);

  const wavesSVG=(c='#ff8fb1')=>`<canvas class="waves" data-c="${c}" width="52" height="32"></canvas>`;
  const ring=(lv,charging)=>{const c=lv<=20?'#ff5a5a':lv<=40?'#ffb34d':'#4ade80',r=9,cf=2*Math.PI*r;
    return `<svg class="ring" viewBox="0 0 22 22"><circle cx="11" cy="11" r="${r}" fill="none" stroke="rgba(255,255,255,.18)" stroke-width="2.4"/><circle cx="11" cy="11" r="${r}" fill="none" stroke="${c}" stroke-width="2.4" stroke-linecap="round" stroke-dasharray="${cf}" stroke-dashoffset="${cf*(1-lv/100)}" transform="rotate(-90 11 11)" style="transition:stroke-dashoffset 1s"/>${charging?`<text x="11" y="14.5" text-anchor="middle" font-size="9" fill="${c}">⚡</text>`:`<text x="11" y="14" text-anchor="middle" font-size="7.5" font-weight="700" fill="#fff">${lv}</text>`}</svg>`};
  const icons={mouse:'🖱',airpods:'🎧',keyboard:'⌨️'};

  const states={
    music:{w:272,h:32,html:`<div class="n-row"><div class="n-art"></div>${wavesSVG()}</div>`,cap:'Music · waves'},
    peek:{w:300,h:66,html:`<div class="n-row"><div class="n-art"></div>${wavesSVG()}</div><div class="n-bottom">Midnight City<span class="n-sub">M83</span></div>`,cap:'Sneak peek · new song'},
    volume:{w:240,h:62,html:`<div class="n-row"><span>🔊</span><b style="font-size:12px" id="hv">62</b></div><div class="n-bottom" style="padding:0 18px"><div class="bar"><i id="hb" style="width:62%"></i></div></div>`,cap:'Volume HUD',run:hud},
    brightness:{w:240,h:62,html:`<div class="n-row"><span>☀️</span><b style="font-size:12px" id="hv">40</b></div><div class="n-bottom" style="padding:0 18px"><div class="bar"><i id="hb" style="width:40%"></i></div></div>`,cap:'Brightness HUD',run:hud},
    mute:{w:240,h:62,html:`<div class="n-row"><span>🔇</span><b style="font-size:12px">0</b></div><div class="n-bottom" style="padding:0 18px"><div class="bar"><i style="width:0"></i></div></div>`,cap:'Muted'},
    pair:{w:440,h:58,html:`<div class="n-row"><span class="spin" style="display:inline-block;font-size:16px">🖱</span><span id="pr">📶</span></div><div class="n-bottom">Magic Mouse<span class="n-sub" id="ps">Connecting…</span></div>`,cap:'NEW · Bluetooth pairing',run:pair},
    airpods:{w:440,h:58,html:`<div class="n-row"><span class="spin" style="display:inline-block;font-size:16px">🎧</span><span id="pr">📶</span></div><div class="n-bottom">AirPods Pro<span class="n-sub" id="ps">Connecting…</span></div>`,cap:'NEW · AirPods battery',run:el=>pair(el,true)},
    charging:{w:350,h:32,html:`<div class="n-row"><b style="color:#4ade80;font-size:12px">Charging</b><span style="font-size:12px">78% 🔋⚡</span></div>`,cap:'Charging'},
    open:{w:640,h:200,open:true,html:`<div class="n-row" style="opacity:.8;font-size:12px"><span>🏠 &nbsp;🗂</span><span>⚙︎ &nbsp;84% 🔋</span></div><div class="n-open"><div class="big-art"></div><div class="pl" style="flex:1"><h4>Midnight City</h4><p>M83 · Hurry Up, We're Dreaming</p><div class="scr"><i></i></div><div class="ctl"><span>⤨</span><span>⏮</span><span>⏸</span><span>⏭</span><span>↻</span></div></div><div class="cal"><b>Today</b><div class="ev"><i style="background:#7c9cff"></i><div>Design review<small>10:00 – 10:30</small></div></div><div class="ev"><i style="background:#ff8fb1"></i><div>Lunch with Sam<small>13:00</small></div></div><div class="ev"><i style="background:#5fd9b6"></i><div>Ship Sentra 🚀<small>Reminder</small></div></div></div></div>`,cap:'Open notch · hover'},
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
  const order=['music','peek','volume','pair','brightness','charging','airpods','mute','open'];
  const labels={music:'Music',peek:'Sneak peek',volume:'Volume',pair:'Mouse pairing',brightness:'Brightness',charging:'Charging',airpods:'AirPods',mute:'Mute',open:'Open notch'};
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
