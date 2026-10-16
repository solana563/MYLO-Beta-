// Adds the permissions background audio and local songs need. Safe to run repeatedly.
import {readFileSync,writeFileSync,existsSync} from "node:fs";
import {dirname,join} from "node:path";
import {fileURLToPath} from "node:url";
const p=join(dirname(fileURLToPath(import.meta.url)),"..","android","app","src","main","AndroidManifest.xml");
if(!existsSync(p)){console.log("no android project yet");process.exit(0)}
let x=readFileSync(p,"utf8");
const perms=[
 '<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
 '<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />',
 '<uses-permission android:name="android.permission.WAKE_LOCK" />',
 '<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
 '<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />',
 '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />'
];
let add="";for(const l of perms){const n=l.match(/name="([^"]+)"/)[1];if(!x.includes(n))add+="    "+l+"\n"}
if(add)x=x.replace(/<\/manifest>\s*$/,add+"</manifest>");
writeFileSync(p,x);console.log(add?"permissions added":"permissions already present");
