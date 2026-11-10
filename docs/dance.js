// Neon dancers — same poses/maths as the Swift app.
(function(){
const P=v=>{const o=[];for(let i=0;i<v.length;i+=2)o.push([v[i],v[i+1]]);return o};
const mir=p=>{const m=p.map(q=>[1-q[0],q[1]]);return [m[0],m[1],m[2],m[5],m[6],m[3],m[4],m[9],m[10],m[7],m[8]]};
const hb=P([0.55,0.12,0.52,0.24,0.48,0.54,0.38,0.37,0.33,0.52,0.67,0.19,0.82,0.07,0.41,0.76,0.40,0.97,0.66,0.58,0.57,0.80]);
const HIP=[P([0.50,0.10,0.50,0.22,0.50,0.52,0.36,0.30,0.27,0.15,0.66,0.34,0.75,0.48,0.42,0.72,0.37,0.96,0.60,0.72,0.67,0.96]),hb,P([0.45,0.19,0.48,0.31,0.52,0.61,0.33,0.41,0.28,0.57,0.65,0.40,0.75,0.29,0.37,0.77,0.29,0.97,0.67,0.79,0.74,0.97]),mir(hb)];
const ga=P([0.40,0.12,0.42,0.22,0.48,0.48,0.30,0.22,0.15,0.14,0.58,0.12,0.66,0.02,0.48,0.72,0.48,0.98,0.67,0.45,0.88,0.35]);
const BAL=[ga,P([0.50,0.12,0.50,0.22,0.50,0.50,0.42,0.10,0.48,0.01,0.58,0.10,0.52,0.01,0.48,0.73,0.49,0.98,0.58,0.65,0.50,0.74]),P([0.50,0.12,0.50,0.22,0.50,0.50,0.34,0.27,0.18,0.30,0.66,0.27,0.82,0.30,0.46,0.74,0.44,0.98,0.56,0.74,0.58,0.98]),mir(ga)];
function pose(ps,t,bpm){const b=t*bpm/60,i=Math.floor(b)%ps.length;let f=b-Math.floor(b);f=f*f*(3-2*f);const a=ps[i],c=ps[(i+1)%ps.length];return a.map((q,k)=>[q[0]+(c[k][0]-q[0])*f,q[1]+(c[k][1]-q[1])*f])}
function dancer(x,R,girl,t,accent){
  const p=pose(girl?BAL:HIP,t,girl?70:100),bounce=girl?0:Math.abs(Math.sin(t*Math.PI*100/60))*0.02;
  const pt=i=>[R.x+p[i][0]*R.w,R.y+(p[i][1]-bounce)*R.h],s=R.h;
  const main=girl?'#ff4fd8':'#ff6a2b',second=girl?'#6f8dff':'#2fd6ff';
  const parts=[]; // [path,width,color]
  const line=(a,b,c)=>{const q=new Path2D();q.moveTo(...a);c?q.quadraticCurveTo(...c,...b):q.lineTo(...b);return q};
  const hd=pt(0),nk=pt(1),pv=pt(2),hr=s*0.07;
  // torso (tube from neck to pelvis)
  parts.push([line(nk,pv),s*(girl?0.11:0.15),main]);
  // arms
  parts.push([line(nk,pt(4),pt(3)),s*(girl?0.045:0.06),main]);parts.push([line(nk,pt(6),pt(5)),s*(girl?0.045:0.06),main]);
  // legs
  const lt=girl?[pv[0],pv[1]+s*.02]:pv;
  parts.push([line(lt,pt(8),pt(7)),s*(girl?0.055:0.08),second]);parts.push([line(lt,pt(10),pt(9)),s*(girl?0.055:0.08),second]);
  // head (and hood / bun)
  parts.push([line(hd,[hd[0]+.01,hd[1]]),hr*2,main]);
  if(girl){parts.push([line([hd[0]+hr*.3,hd[1]-hr*1.1],[hd[0]+hr*.31,hd[1]-hr*1.1]),hr*.9,main]);
    // tutu: wide flat tube across the hips that flutters
    const fl=Math.sin(t*6)*s*.015;parts.push([line([pv[0]-s*.17,pv[1]+s*.03+fl],[pv[0]+s*.17,pv[1]+s*.03-fl],[pv[0],pv[1]-s*.02]),s*.07,second]);}
  else{parts.push([line([hd[0]-hr*.2,hd[1]-hr*.2],[hd[0]+hr*.3,hd[1]+hr*.2]),hr*2.5,main]);
    for(const f of[8,10]){const q=pt(f);parts.push([line([q[0]-s*.025,q[1]],[q[0]+s*.045,q[1]]),s*.06,'#ffd34d'])}}
  // light trails
  const trails=new Path2D();
  for(let k=0;k<3;k++){const ph=t*(1.1+k*.35)+k*2.1,cx=R.x+R.w/2,cy=R.y+R.h/2,rx=R.w*(.46+.06*k),ry=R.h*(.32+.05*k);for(let j=0;j<=12;j++){const an=ph+j*.13,q=[cx+Math.cos(an)*rx,cy+Math.sin(an*1.3)*ry];j?trails.lineTo(...q):trails.moveTo(...q)}}
  const edge=Math.max(1,s*.022);x.lineCap='round';x.lineJoin='round';
  x.save();x.filter=`blur(${Math.max(1.5,s*.05)}px)`;x.globalAlpha=.9;for(const[q,w,c]of parts){x.strokeStyle=c;x.lineWidth=w+edge*3;x.stroke(q)}x.restore();
  x.globalAlpha=.35;x.strokeStyle=accent;x.lineWidth=Math.max(.8,s*.012);x.stroke(trails);x.globalAlpha=1;
  for(const[q,w,c]of parts){x.strokeStyle=c;x.lineWidth=w;x.stroke(q)}
  for(const[q,w,c]of parts){x.strokeStyle='#000';x.lineWidth=Math.max(0,w-edge*2);x.stroke(q)}
  for(const[q,w,c]of parts){x.strokeStyle=c;x.globalAlpha=.13;x.lineWidth=Math.max(0,w-edge*2);x.stroke(q)}x.globalAlpha=1;
  x.fillStyle=girl?'rgba(255,79,216,.5)':'rgba(47,214,255,.5)';x.beginPath();x.ellipse(R.x+R.w/2,R.y+R.h-1,R.w*.32,1.5,0,0,Math.PI*2);x.fill();
}
window.drawDancers=function(cv,who,t,accent){const x2=cv.getContext('2d');x=x2;const W=cv.width,H=cv.height;x.clearRect(0,0,W,H);const list=who=='boy'?[0]:who=='girl'?[1]:[0,1];const w=W/list.length;
  list.forEach((g,i)=>{const fw=Math.min(w,H*.9);dancer(x,{x:i*w+(w-fw)/2,y:0,w:fw,h:H},!!g,t+i*.5,accent||'#7c9cff')})};
let x;
})();
