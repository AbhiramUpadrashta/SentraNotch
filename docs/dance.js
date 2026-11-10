// Disco dancers — same maths as the Swift app (Visualizers.swift).
(function(){
const P=v=>{const o=[];for(let i=0;i<v.length;i+=2)o.push([v[i],v[i+1]]);return o};
const mir=p=>{const m=p.map(q=>[1-q[0],q[1]]);return [m[0],m[1],m[2],m[5],m[6],m[3],m[4],m[9],m[10],m[7],m[8]]};
// head, neck, pelvis, lElbow, lHand, rElbow, rHand, lKnee, lFoot, rKnee, rFoot
const D1=P([0.50,0.14,0.50,0.26,0.52,0.55,0.40,0.42,0.47,0.53,0.66,0.16,0.80,0.03,0.44,0.76,0.40,0.97,0.62,0.75,0.66,0.97]);
const D2=P([0.48,0.16,0.49,0.28,0.50,0.57,0.37,0.44,0.22,0.62,0.61,0.42,0.55,0.53,0.40,0.77,0.36,0.97,0.60,0.77,0.64,0.97]);
const D3=P([0.53,0.15,0.52,0.27,0.57,0.56,0.41,0.37,0.53,0.35,0.65,0.40,0.54,0.42,0.47,0.77,0.43,0.97,0.65,0.75,0.69,0.97]);
const MOVES=[D1,D2,D3,mir(D1),mir(D2),mir(D3)];
const hsl=(h,l=60)=>`hsl(${(h%360+360)%360},100%,${l}%)`;
function pose(t,bpm,off){const b=t*bpm/60+off,i=Math.floor(b)%MOVES.length;let f=b-Math.floor(b);f=Math.min(1,f*1.6);f=f*f*(3-2*f);const a=MOVES[i],c=MOVES[(i+1)%MOVES.length];return a.map((q,k)=>[q[0]+(c[k][0]-q[0])*f,q[1]+(c[k][1]-q[1])*f])}
let x;
function tube(a,b,c,w,col){x.strokeStyle=col;x.lineWidth=w;x.beginPath();x.moveTo(...a);c?x.quadraticCurveTo(...c,...b):x.lineTo(...b);x.stroke()}
function figure(R,girl,t,hue){
  const bpm=116,p=pose(t,bpm,girl?3:0),bob=Math.abs(Math.sin(t*Math.PI*bpm/60))*0.025;
  const pt=i=>[R.x+p[i][0]*R.w,R.y+(p[i][1]+bob)*R.h],s=R.h;
  const c1=hsl(hue),c2=hsl(hue+50,62),edge=Math.max(1,s*.024);
  const hd=pt(0),nk=pt(1),pv=pt(2),hr=s*.075;
  x.lineCap='round';x.lineJoin='round';
  // each piece: glow, neon tube, then hollow — back to front so arms show over the body
  const piece=(draw,w,col)=>{x.save();x.filter=`blur(${Math.max(1.5,s*.045)}px)`;draw(w+edge*3,col);x.restore();draw(w,col);draw(Math.max(0,w-edge*2),'#05040a')};
  const T=(a,b,c)=>(w,col)=>tube(a,b,c,w,col);
  piece(T(pv,pt(8),pt(7)),s*.065,c2);piece(T(pv,pt(10),pt(9)),s*.065,c2);
  if(!girl)for(const f of[8,10]){const q=pt(f);piece(T([q[0]-s*.04,q[1]-s*.015],[q[0]+s*.04,q[1]-s*.015]),s*.06,c2)} // bell-bottoms
  piece(T(nk,pv),s*(girl?.1:.13),c1);
  if(girl){ // dress: a flared outline
    const sw=Math.sin(t*Math.PI*bpm/60)*s*.03,top=pv[1]-s*.1,bot=pv[1]+s*.14;
    const dress=(w,col)=>{x.strokeStyle=col;x.lineWidth=Math.max(1,w);x.beginPath();x.moveTo(pv[0]-s*.05,top);x.lineTo(pv[0]-s*.17+sw,bot);x.quadraticCurveTo(pv[0]+sw,bot+s*.04,pv[0]+s*.17+sw,bot);x.lineTo(pv[0]+s*.05,top);x.closePath();
      if(col=='#05040a'){x.fillStyle=col;x.fill()}else x.stroke()};
    x.save();x.filter=`blur(${Math.max(1.5,s*.045)}px)`;dress(edge*3,c2);x.restore();dress(0,'#05040a');dress(edge*1.2,c2);
    // hair flowing behind the head
    const sway=Math.sin(t*7)*hr*.6;piece(T([hd[0]-hr*.4,hd[1]-hr*.3],[hd[0]-hr*1.5+sway,hd[1]+hr*2.2],[hd[0]-hr*1.6,hd[1]+hr*.4]),hr*.9,c1);
  }
  piece(T(nk,pt(4),pt(3)),s*.05,c1);piece(T(nk,pt(6),pt(5)),s*.05,c1);
  if(!girl)piece(T([hd[0],hd[1]-hr*.25],[hd[0]+.01,hd[1]-hr*.25]),hr*2.9,c1); // afro
  piece(T(hd,[hd[0]+.01,hd[1]]),hr*2,c1);
}
function scene(cv,who,t){
  x=cv.getContext('2d');const W=cv.width,H=cv.height;x.clearRect(0,0,W,H);
  const bpm=116,beat=t*bpm/60,hue=(Math.floor(beat)*47)%360;
  // floor tiles
  const n=8,tw=W/n,fy=H*.9;for(let i=0;i<n;i++){const on=(Math.floor(beat)+i)%3==0;x.fillStyle=on?hsl(hue+i*40,55):'rgba(255,255,255,.06)';x.globalAlpha=on?.55:1;x.fillRect(i*tw+1,fy,tw-2,H-fy);}x.globalAlpha=1;
  // beams from the ball
  const bx=W/2,by=H*.1;for(let k=0;k<3;k++){const a=Math.PI/2+Math.sin(t*1.3+k*2.1)*0.9,sp=.12;x.fillStyle=hsl(hue+k*120,60);x.globalAlpha=.16;x.beginPath();x.moveTo(bx,by);x.lineTo(bx+Math.cos(a-sp)*H*2,by+Math.sin(a-sp)*H*2);x.lineTo(bx+Math.cos(a+sp)*H*2,by+Math.sin(a+sp)*H*2);x.fill()}x.globalAlpha=1;
  // dancers
  const list=who=='boy'?[0]:who=='girl'?[1]:[0,1],fw=Math.min(W/list.length,H*.75),gap=(W-fw*list.length)/(list.length+1);
  list.forEach((g,i)=>figure({x:gap+i*(fw+gap),y:H*.12,w:fw,h:H*.8},!!g,t,hue+i*140));
  // disco ball
  const br=Math.max(3,H*.1);x.save();x.beginPath();x.arc(bx,by,br,0,Math.PI*2);x.clip();
  x.fillStyle='#c9d1e8';x.fillRect(bx-br,by-br,br*2,br*2);x.strokeStyle='#5a6378';x.lineWidth=Math.max(.5,br*.12);
  for(let k=-3;k<=3;k++){const yy=by+k*br/3.2;x.beginPath();x.moveTo(bx-br,yy);x.lineTo(bx+br,yy);x.stroke()}
  const rot=(t*1.5)%1;for(let k=-3;k<=4;k++){const xx=bx+Math.sin((k/4+rot/4)*Math.PI)*br;x.beginPath();x.moveTo(xx,by-br);x.lineTo(xx,by+br);x.stroke()}
  x.restore();
  for(let k=0;k<4;k++){const tw2=(Math.sin(t*9+k*1.9)+1)/2;if(tw2>.7){const a=k*1.6+t,sx=bx+Math.cos(a)*br*1.8,sy=by+Math.sin(a)*br*1.3+br*.6;x.fillStyle='#fff';x.globalAlpha=tw2;x.fillRect(sx-.5,sy-br*.5,1,br);x.fillRect(sx-br*.5,sy-.5,br,1);x.globalAlpha=1}}
}
window.drawDancers=function(cv,who,t){scene(cv,who||'both',t)};
})();
