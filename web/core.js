(function(root){
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
const id=()=>Date.now().toString(36)+'-'+Math.random().toString(36).slice(2,10);
const materials={drywall:{name:'Vách thạch cao',loss:3},brick:{name:'Tường gạch',loss:8},concrete:{name:'Bê tông',loss:15},glass:{name:'Kính',loss:2},wood:{name:'Gỗ / cửa',loss:3},metal:{name:'Kim loại',loss:25}};
function floor(name='Tầng 1'){return {id:id(),name,width:30,height:20,elevation:0,image:null,walls:[],aps:[],snapshots:[{id:id(),name:'Snapshot 1',points:[]}]};}
function project(name='Dự án mới'){return {format:'wifiscope',version:2,id:id(),name,createdAt:new Date().toISOString(),modifiedAt:new Date().toISOString(),pathLoss:2.8,slabLoss:15,floors:[floor()]};}
const finite=(v)=>typeof v==='number'&&Number.isFinite(v);
function validate(p){
 if(!p||p.format!=='wifiscope'||p.version!==2||typeof p.name!=='string'||!Array.isArray(p.floors)||!p.floors.length||p.floors.length>100)throw Error('Tệp không phải dự án WiFi Scope v2 hợp lệ.');
 if(!finite(p.pathLoss)||p.pathLoss<1||p.pathLoss>6||!finite(p.slabLoss)||p.slabLoss<0||p.slabLoss>60)throw Error('Thông số mô phỏng không hợp lệ.');
 const ids=new Set();const uid=v=>{if(typeof v!=='string'||!v||ids.has(v))throw Error('ID bị trùng hoặc không hợp lệ.');ids.add(v);};uid(p.id);
 for(const f of p.floors){uid(f.id);if(typeof f.name!=='string'||!finite(f.width)||f.width<=0||f.width>1000||!finite(f.height)||f.height<=0||f.height>1000||!finite(f.elevation)||Math.abs(f.elevation)>1000||!Array.isArray(f.walls)||!Array.isArray(f.aps)||!Array.isArray(f.snapshots)||!f.snapshots.length)throw Error('Thông số tầng không hợp lệ.');
  if(f.image!==null&&(typeof f.image!=='string'||!/^data:image\/(png|jpeg|webp);base64,[a-zA-Z0-9+/=]+$/.test(f.image)))throw Error('Ảnh mặt bằng không hợp lệ.');
  const xy=v=>{if(!finite(v.x)||!finite(v.y)||v.x<0||v.x>1||v.y<0||v.y>1)throw Error('Tọa độ không hợp lệ.');};
  if(f.walls.length>2000||f.aps.length>500||f.snapshots.length>200)throw Error('Dự án vượt giới hạn xử lý.');
  for(const w of f.walls){uid(w.id);xy(w.a);xy(w.b);if(!materials[w.material]||!finite(w.thickness)||w.thickness<1||w.thickness>200)throw Error('Vật liệu không hợp lệ.');}
  for(const a of f.aps){uid(a.id);xy(a);if(typeof a.name!=='string'||!['2.4 GHz','5 GHz','6 GHz'].includes(a.band)||!finite(a.power)||a.power<0||a.power>40||!finite(a.gain)||a.gain<0||a.gain>30||!finite(a.channel)||a.channel<1||a.channel>233)throw Error('AP không hợp lệ.');}
  for(const s of f.snapshots){uid(s.id);if(typeof s.name!=='string'||!Array.isArray(s.points)||s.points.length>5000)throw Error('Snapshot không hợp lệ.');for(const point of s.points){uid(point.id);xy(point);if(typeof point.at!=='string'||!Array.isArray(point.networks)||point.networks.length>3000)throw Error('Điểm đo không hợp lệ.');for(const n of point.networks){if(typeof n.bssid!=='string'||typeof n.ssid!=='string'||!finite(n.dbm)||n.dbm>0||n.dbm< -150||typeof n.band!=='string')throw Error('Dữ liệu radio không hợp lệ.');}}}
 }return p;
}
function intersects(a,b,c,d){const cross=(p,q,r)=>(q.x-p.x)*(r.y-p.y)-(q.y-p.y)*(r.x-p.x);return cross(a,b,c)*cross(a,b,d)<0&&cross(c,d,a)*cross(c,d,b)<0;}
function predict(p,target,x,y){const out=[];for(const f of p.floors){for(const a of f.aps){const tx={x:a.x*f.width,y:a.y*f.height},rx={x:x*target.width,y:y*target.height},vertical=Math.abs(f.elevation-target.elevation),distance=Math.max(1,Math.hypot(tx.x-rx.x,tx.y-rx.y,vertical));const freq=a.band==='2.4 GHz'?2.437:a.band==='5 GHz'?5.5:6.2;
 let loss=0;for(const w of target.walls){const c={x:w.a.x*target.width,y:w.a.y*target.height},d={x:w.b.x*target.width,y:w.b.y*target.height};if(intersects(tx,rx,c,d))loss+=materials[w.material].loss*w.thickness/12;}
 const floorCross=p.floors.filter(z=>z.elevation>Math.min(f.elevation,target.elevation)&&z.elevation<=Math.max(f.elevation,target.elevation)).length;
 const dbm=a.power+a.gain-(32.44+20*Math.log10(freq)+10*p.pathLoss*Math.log10(distance))-loss-floorCross*p.slabLoss;
 out.push({ssid:a.name,bssid:a.id,dbm:clamp(dbm,-140,-10),band:a.band,channel:a.channel,radio:a.band==='6 GHz'?'802.11ax':'802.11ac'});
 }}return out;}
function metric(networks,type,target='all',band='all',threshold=-67){const ns=[...new Map(networks.filter(n=>finite(n.dbm)&&(band==='all'||n.band===band)).sort((a,b)=>a.dbm-b.dbm).map(n=>[n.bssid,n])).values()].sort((a,b)=>b.dbm-a.dbm),scope=target==='all'?ns:ns.filter(n=>n.bssid===target);if(!scope.length)return null;const best=scope[0];
 if(type==='signal'||type==='low')return best.dbm;if(type==='secondary')return ns[1]?.dbm??null;if(type==='count')return scope.filter(n=>n.dbm>=threshold).length;
 if(type==='band')return best.band==='2.4 GHz'?2.4:best.band==='5 GHz'?5:best.band==='6 GHz'?6:null;
 if(type==='phy')return /be/.test(best.radio)?7:/ax/.test(best.radio)?6:/ac/.test(best.radio)?5:/n/.test(best.radio)?4:3;
 if(type==='sir'){const others=ns.filter(n=>n.bssid!==best.bssid&&n.band===best.band&&n.channel===best.channel);if(!others.length)return null;return best.dbm-10*Math.log10(others.reduce((s,n)=>s+10**(n.dbm/10),0));}
 return null;
}
function pointValue(p,type,target='all',band='all',threshold=-67){if(['download','upload','jitter','loss','latency','txRate','rxRate'].includes(type)){if(!p.active||(target!=='all'&&p.active.bssid!==target)||(band!=='all'&&p.active.band!==band))return null;return finite(p.active[type])?p.active[type]:null;}return metric(p.networks,type,target,band,threshold);}
function interpolate(points,f,x,y,type,target,band,radius,threshold){let sum=0,weight=0;const near=[];for(const p of points){const d=Math.hypot((p.x-x)*f.width,(p.y-y)*f.height);if(d>radius)continue;const value=pointValue(p,type,target,band,threshold);if(value===null)continue;if(d<0.02)return value;near.push({d,value});}
 if(!near.length)return null;if(type==='band'||type==='phy')return near.sort((a,b)=>a.d-b.d)[0].value;
 for(const n of near){const w=1/Math.max(.01,n.d*n.d);sum+=n.value*w;weight+=w;}return weight?sum/weight:null;}
function color(v,type,threshold=-67){if(v===null)return null;let t=['download','upload','txRate','rxRate'].includes(type)?clamp(v/500,0,1):['jitter','latency'].includes(type)?clamp(v/100,0,1):type==='loss'?clamp(v/100,0,1):type==='count'?clamp(v/8,0,1):type==='sir'?clamp((v+10)/45,0,1):type==='band'?v===2.4?.15:v===5?.55:.9:type==='phy'?clamp((v-3)/4,0,1):clamp((v+90)/50,0,1);if(type==='low')return v<threshold?'rgba(240,74,74,.65)':'rgba(46,183,121,.48)';const stops=[[49,82,181],[45,173,209],[92,205,142],[246,222,80],[238,71,56]];const s=Math.min(3,Math.floor(t*4)),q=t*4-s;return `rgba(${stops[s].map((n,i)=>Math.round(n+(stops[s+1][i]-n)*q)).join(',')},.68)`;}
function csv(rows){return '\uFEFF'+rows.map(row=>row.map(v=>{let s=String(v??'');if(typeof v==='string'&&/^[=+@\-\t\r]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"';}).join(',')).join('\r\n');}
const api={clamp,id,materials,floor,project,validate,intersects,predict,metric,pointValue,interpolate,color,csv};if(typeof module!=='undefined')module.exports=api;root.ScopeCore=api;
})(globalThis);
