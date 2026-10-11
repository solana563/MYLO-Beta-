"""Layout guard: finds overlapping text, text escaping its card, and horizontal overflow on every screen/theme/size.
Run: python3 overlap.py  (exit code 1 if problems)"""
from playwright.sync_api import sync_playwright
import sys
JS=r'''()=>{
const vis=e=>{const r=e.getBoundingClientRect(),cs=getComputedStyle(e);return r.width>1&&r.height>1&&cs.visibility!=="hidden"&&cs.display!=="none"&&+cs.opacity>0.05};
const layer=e=>e.closest("#nav")?"nav":e.closest("#mini")?"mini":e.closest("#dsb")?"dsb":e.closest("#mdl")?"mdl":e.closest("#full")?"full":e.closest("#lyr")?"lyr":"view";
const els=[...document.querySelectorAll("#app *")].filter(e=>{if(!vis(e))return false;let t="";e.childNodes.forEach(n=>{if(n.nodeType===3)t+=n.textContent});return t.trim().length>0});
const out=[];
for(let i=0;i<els.length;i++)for(let j=i+1;j<els.length;j++){const a=els[i],b=els[j];if(a.contains(b)||b.contains(a)||layer(a)!==layer(b))continue;
 if(a.closest("#full")&&!a.closest("#full").classList.contains("open"))continue;if(a.closest("#lyr")&&!a.closest("#lyr").classList.contains("open"))continue;if(a.closest("#im")||b.closest("#im"))continue;
 const A=a.getBoundingClientRect(),B=b.getBoundingClientRect();if(A.bottom<0||A.top>innerHeight||B.bottom<0||B.top>innerHeight)continue;
 const w=Math.min(A.right,B.right)-Math.max(A.left,B.left),h=Math.min(A.bottom,B.bottom)-Math.max(A.top,B.top);
 if(w>3&&h>3){const sm=Math.min(A.width*A.height,B.width*B.height);if(w*h/sm>.25)out.push("OVERLAP "+a.tagName+"."+a.className+"["+a.textContent.trim().slice(0,16)+"] x "+b.tagName+"."+b.className+"["+b.textContent.trim().slice(0,16)+"]")}}
document.querySelectorAll(".pls>.cd,.recent>.tile").forEach(c=>{const i=c.querySelector("i")||c;const R=i.getBoundingClientRect();c.querySelectorAll("b,small,span.mt").forEach(t=>{if(!vis(t))return;const r=t.getBoundingClientRect();if(r.bottom>R.bottom+2&&!c.querySelector("i.nw")&&!t.closest(".mixc")===false&&false)out.push("ESCAPE "+t.textContent.slice(0,16))
 if(!c.querySelector("i.nw")&&(r.bottom>R.bottom+2||r.top<R.top-2))out.push("ESCAPE "+t.tagName+"["+t.textContent.trim().slice(0,16)+"] outside art")})});
const v=document.getElementById("view");if(v&&v.scrollWidth>v.clientWidth+2)out.push("HSCROLL view "+v.scrollWidth+">"+v.clientWidth);
els.forEach(e=>{if(layer(e)==="nav")return;const r=e.getBoundingClientRect();if(r.left<-1||r.right>innerWidth+1){if(!e.closest(".pls,.story,.recent,.chips,.ex,.hubg"))out.push("OFFSCREEN "+e.tagName+"["+e.textContent.trim().slice(0,16)+"]")}});
return out}'''
STEPS=[('Home',"go('Home')"),('Search',"go('Search')"),('Discover',"go('Discover')"),('Library',"go('Library')"),('Lib-Albums',"go('Library');S.lib='Albums';render()"),('Lib-Playlists',"go('Library');S.lib='Playlists';render()"),('Profile',"go('Profile')"),('Album',"S.nav='album:'+albums()[0].id;render()"),('Artist',"S.nav='artist:'+artists()[0].id;render()"),('Playlist',"S.nav='pl:x1';render()"),('Liked',"S.nav='pl:liked';render()"),('Recent',"S.nav='recent:all';render()"),('TrackMenu',"S.nav=null;go('Home');trackMenu(1)"),('Sound',"closeM();soundM()"),('NowPlaying',"closeM();openFull()")]
bad=0
with sync_playwright() as p:
    b=p.chromium.launch(args=['--autoplay-policy=no-user-gesture-required'])
    for vw,vh in ((360,740),(430,860),(1280,800)):
        for th in ('dark','light'):
            pg=b.new_page(viewport={'width':vw,'height':vh})
            pg.goto('file:///mnt/user-data/outputs/milo-app/index.html');pg.wait_for_timeout(1800)
            pg.evaluate(f"T.forEach((t,i)=>{{t.hid=false;t.al=i<4?'Night Drive':'Daylight';t.d=t.d||200}});$('app').dataset.theme='{th}';S.hist=T.slice(0,3).map(t=>t.key);S.pls.push({{id:'x1',name:'A very long playlist name for testing',keys:T.slice(0,3).map(t=>t.key)}});S.likes.add(T[0].key);play(0)")
            for n,js in STEPS:
                pg.evaluate(js);pg.wait_for_timeout(900)
                r=pg.evaluate(JS)
                if r:
                    bad+=len(r);print(f"{vw}x{vh} {th} {n}:");[print("   ",x) for x in r[:6]]
            pg.close()
    b.close()
print("problems:",bad);sys.exit(1 if bad else 0)
