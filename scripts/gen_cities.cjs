#!/usr/bin/env node
'use strict';
const fs = require('fs');
const path = require('path');

const KRC_BLD = {
  usDay: [[0xf5e8c8,0x5599ff,10,32,8,14],[0xe8d4a8,0xff8833,8,25,7,12],[0xfaf0d8,0x33cc88,12,40,9,15],[0xdcc8a0,0xffcc44,9,28,8,13],[0xf0e0c0,0x4488ff,14,46,10,16],[0xe4d4b0,0xff6644,11,36,7,11]],
  gulf: [[0xd4a040,0xffcc00,22,80,10,18],[0xc88020,0xff6600,16,55,8,14],[0xe8c060,0xffffff,25,90,12,20],[0xd09030,0xffaa00,18,60,9,16],[0xdcb050,0xffdd44,20,70,10,17],[0xc89438,0xff8833,15,50,8,13]],
  neon: [[0x0d1525,0x0044ff,18,55,8,14],[0x12101a,0xff00cc,12,40,7,12],[0x0a1510,0x00ffaa,20,60,9,15],[0x1a0d0d,0xff2200,15,45,8,13],[0x111118,0x00aaff,25,70,10,16],[0x0f0f18,0xffcc00,14,38,7,11]],
  euro: [[0xe8e0d0,0x6688aa,12,38,8,13],[0xd8d0c0,0x99aabb,10,30,7,11],[0xf0ece4,0x778899,14,42,9,14],[0xc8c0b0,0x556677,9,26,7,10],[0xe0dcd4,0x8899aa,13,40,8,12],[0xd0ccc4,0x667788,11,32,7,11]],
  tropical: [[0xf0e8c8,0x44aa66,11,34,8,13],[0xe8dcc0,0xff8844,9,28,7,11],[0xf8f0d8,0x33bb77,13,38,9,14],[0xe0d4b8,0xffaa33,10,30,7,10],[0xf4ecd8,0x55cc88,12,36,8,12],[0xd8ccb0,0xff9933,9,26,7,10]],
  industrial: [[0xc8c4bc,0x8899aa,14,40,8,13],[0xb8b4ac,0x667788,11,32,7,11],[0xd0ccc4,0x99aabb,16,44,9,14],[0xa8a49c,0x556677,10,28,7,10],[0xc0bcb4,0x778899,13,38,8,12],[0xb0aca4,0x667788,11,30,7,10]]
};

const T = {
  nycNight: { isDay:false,isSunset:false,isNight:true, sky:0x050810,fogColor:0x050810,fogNear:0,fogFar:0, groundCol:0x101018, ambCol:0x223355,ambInt:0.5, sunCol:0x99bbff,sunInt:0.4,sunPos:[50,100,70], fillCol:0x2244aa,fillInt:0.35, hemisSky:0x223355,hemisGnd:0x080810,hemisInt:0.32, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.neon, skylineWin:[0x3366ff,0xff2266,0x00ccaa,0xffcc00,0x4488ff], treeColor:0x0a220a,treeTrunk:0x2a1200, previewGrad:['#050810','#2244aa','#ff2266'], cityLights:[[0x3366ff,190],[0xff2266,210],[0x00ccaa,170],[0xffcc00,160]] },
  tokyoNeon: { isDay:false,isSunset:false,isNight:true, sky:0x02030a,fogColor:0x02030a,fogNear:0,fogFar:0, groundCol:0x0e0e14, ambCol:0x112244,ambInt:0.45, sunCol:0xaaccff,sunInt:0.35,sunPos:[40,120,60], fillCol:0x0066ff,fillInt:0.3, hemisSky:0x112244,hemisGnd:0x050510,hemisInt:0.3, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.neon, skylineWin:[0x0055ff,0xff00aa,0x00ffcc,0xffaa00,0x00aaff], treeColor:0x0a2a0a,treeTrunk:0x2a1200, previewGrad:['#02030a','#0044ff','#ff00cc'], cityLights:[[0x0044ff,180],[0xff0066,200],[0x00ffaa,180],[0xffaa00,170]] },
  dubaiSunset: { isDay:false,isSunset:true,isNight:false, sky:0xe8642a,cloudCol:0xffccaa,cloudOp:0.65, fogColor:0xc05010,fogNear:50,fogFar:260, groundCol:0xc4a820, ambCol:0xff9966,ambInt:0.55, sunCol:0xff5500,sunInt:1.6,sunPos:[250,30,10], fillCol:0xff6633,fillInt:0.4, hemisSky:0xe8642a,hemisGnd:0xc4a820,hemisInt:0.45, curbA:0xffcc00,curbB:0xffffff, bldConfigs:KRC_BLD.gulf, skylineWin:[0xffcc00,0xff6600,0xffffff,0xffaa00,0xffdd44], treeColor:0x3d5c10,treeTrunk:0x7a5020, previewGrad:['#e8642a','#d4a040','#c4a820'], cityLights:[] },
  londonRain: { isDay:false,isSunset:false,isNight:false, sky:0x8a9aaa,cloudCol:0xb0b8c0,cloudOp:0.85, fogColor:0x9aa8b8,fogNear:40,fogFar:220, groundCol:0x4a6a38, ambCol:0xc0c8d0,ambInt:0.55, sunCol:0xd8e0e8,sunInt:1.1,sunPos:[80,120,40], fillCol:0xa0b0c0,fillInt:0.4, hemisSky:0x8a9aaa,hemisGnd:0x4a5a40,hemisInt:0.45, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.euro, skylineWin:[0x8899aa,0x99aabb,0x667788,0xaabbcc,0x778899], treeColor:0x2a5a20,treeTrunk:0x4a3018, previewGrad:['#8a9aaa','#c0c8d0','#4a6a38'], cityLights:[] },
  laDay: { isDay:true,isSunset:false,isNight:false, sky:0x6abaed,cloudCol:0xffffff,cloudOp:0.9, fogColor:0xc4dff5,fogNear:100,fogFar:420, groundCol:0x5a8a30, ambCol:0xfff8f0,ambInt:0.75, sunCol:0xfff4d0,sunInt:2.8,sunPos:[120,200,80], fillCol:0xb0d8ff,fillInt:0.55, hemisSky:0x6abaed,hemisGnd:0x5a8a30,hemisInt:0.5, curbA:0xff3311,curbB:0xffffff, bldConfigs:KRC_BLD.usDay, skylineWin:[0x5599ff,0x33cc88,0xffcc44,0xff8833,0x4488ff], treeColor:0x2d7a20,treeTrunk:0x6b3a1f, previewGrad:['#6abaed','#f5deb3','#5a8a30'], cityLights:[] },
  miamiNeon: { isDay:false,isSunset:true,isNight:false, sky:0xff7744,cloudCol:0xffccaa,cloudOp:0.7, fogColor:0xff8855,fogNear:60,fogFar:280, groundCol:0x3a7a28, ambCol:0xffaa88,ambInt:0.6, sunCol:0xff6622,sunInt:1.8,sunPos:[200,50,30], fillCol:0xff8866,fillInt:0.45, hemisSky:0xff7744,hemisGnd:0x2a6a20,hemisInt:0.48, curbA:0xff3311,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0xff66aa,0x00ccff,0xffcc00,0xff4400,0x44ddff], treeColor:0x1a6a18,treeTrunk:0x5a3810, previewGrad:['#ff7744','#ffccaa','#2a6a20'], cityLights:[[0xff44aa,160],[0x00ccff,150]] },
  rioTropical: { isDay:true,isSunset:false,isNight:false, sky:0x5ac8ee,cloudCol:0xffffff,cloudOp:0.7, fogColor:0xa8e8f8,fogNear:85,fogFar:390, groundCol:0x4a9a38, ambCol:0xfff8e8,ambInt:0.78, sunCol:0xfff0c0,sunInt:2.5,sunPos:[95,175,55], fillCol:0x88ddff,fillInt:0.5, hemisSky:0x5ac8ee,hemisGnd:0x4a9a38,hemisInt:0.5, curbA:0xff3311,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0x44ccff,0xffaa44,0x33dd88,0xff6644,0x88eeff], treeColor:0x228818,treeTrunk:0x6a4018, previewGrad:['#5ac8ee','#fff0c0','#4a9a38'], cityLights:[] },
  vegasNight: { isDay:false,isSunset:false,isNight:true, sky:0x0a0518,fogColor:0x0a0518,fogNear:0,fogFar:0, groundCol:0x1a1420, ambCol:0x331144,ambInt:0.48, sunCol:0xff88ff,sunInt:0.45,sunPos:[30,90,50], fillCol:0xff00aa,fillInt:0.35, hemisSky:0x331144,hemisGnd:0x100818,hemisInt:0.3, curbA:0xffcc00,curbB:0xffffff, bldConfigs:KRC_BLD.gulf, skylineWin:[0xff00cc,0xffcc00,0x00ffff,0xff4400,0xff66ff], treeColor:0x1a3010,treeTrunk:0x4a2810, previewGrad:['#0a0518','#ff00cc','#ffcc00'], cityLights:[[0xff00cc,200],[0xffcc00,190],[0x00ffff,170]] },
  chicagoFog: { isDay:false,isSunset:false,isNight:false, sky:0xa08060,cloudCol:0xb8a898,cloudOp:0.8, fogColor:0x908070,fogNear:30,fogFar:200, groundCol:0x4a5a38, ambCol:0xc8b8a8,ambInt:0.5, sunCol:0xffaa66,sunInt:1.2,sunPos:[100,80,20], fillCol:0x998877,fillInt:0.38, hemisSky:0xa08060,hemisGnd:0x4a5040,hemisInt:0.42, curbA:0xcc2200,curbB:0xffffff, bldConfigs:KRC_BLD.industrial, skylineWin:[0x8899aa,0xffaa66,0x667788,0x99aabb,0x776655], treeColor:0x2a4a20,treeTrunk:0x3a2818, previewGrad:['#a08060','#c8b8a8','#4a5a38'], cityLights:[] },
  dublinRain: { isDay:false,isSunset:false,isNight:false, sky:0x7a9a88,cloudCol:0xa0b8a8,cloudOp:0.88, fogColor:0x88a898,fogNear:50,fogFar:240, groundCol:0x3d6a32, ambCol:0xb8d0c0,ambInt:0.58, sunCol:0xd0e8d8,sunInt:1.15,sunPos:[70,130,50], fillCol:0x90b0a0,fillInt:0.42, hemisSky:0x7a9a88,hemisGnd:0x3d6a32,hemisInt:0.46, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.euro, skylineWin:[0x668877,0x99bbaa,0x445566,0xaaccbb,0x556677], treeColor:0x2a6a28,treeTrunk:0x4a3018, previewGrad:['#7a9a88','#b8d0c0','#3d6a32'], cityLights:[] },
  honoluluTropical: { isDay:true,isSunset:false,isNight:false, sky:0x5ac8ee,cloudCol:0xffffff,cloudOp:0.75, fogColor:0xa8e8f8,fogNear:90,fogFar:400, groundCol:0x4a9a38, ambCol:0xfff8e8,ambInt:0.8, sunCol:0xfff0c0,sunInt:2.6,sunPos:[100,180,60], fillCol:0x88ddff,fillInt:0.5, hemisSky:0x5ac8ee,hemisGnd:0x4a9a38,hemisInt:0.52, curbA:0xff3311,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0x44ccff,0xffaa44,0x33dd88,0xff6644,0x88eeff], treeColor:0x228818,treeTrunk:0x6a4018, previewGrad:['#5ac8ee','#fff0c0','#4a9a38'], cityLights:[] },
  detroitNight: { isDay:false,isSunset:false,isNight:true, sky:0x080a12,fogColor:0x080a12,fogNear:0,fogFar:0, groundCol:0x121418, ambCol:0x223344,ambInt:0.42, sunCol:0x8899bb,sunInt:0.32,sunPos:[60,90,40], fillCol:0x334455,fillInt:0.28, hemisSky:0x223344,hemisGnd:0x0a0c10,hemisInt:0.28, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.industrial, skylineWin:[0x556677,0xffaa44,0x8899aa,0x334455,0x667788], treeColor:0x0a1a0a,treeTrunk:0x2a1808, previewGrad:['#080a12','#334455','#8899bb'], cityLights:[[0xffaa44,140],[0x6688aa,150]] },
  phoenixDesert: { isDay:true,isSunset:false,isNight:false, sky:0x88c8f0,cloudCol:0xffffff,cloudOp:0.35, fogColor:0xc8e0f0,fogNear:120,fogFar:450, groundCol:0xc8a858, ambCol:0xfff4e0,ambInt:0.78, sunCol:0xffe8b0,sunInt:2.9,sunPos:[140,190,40], fillCol:0xffddaa,fillInt:0.5, hemisSky:0x88c8f0,hemisGnd:0xc8a858,hemisInt:0.48, curbA:0xff4400,curbB:0xffffff, bldConfigs:KRC_BLD.gulf, skylineWin:[0xffaa44,0xffcc66,0xdd8844,0xff8844,0xeebb66], treeColor:0x4a6820,treeTrunk:0x6a4818, previewGrad:['#88c8f0','#ffe8b0','#c8a858'], cityLights:[] },
  seattleFog: { isDay:false,isSunset:false,isNight:false, sky:0x98a8b8,cloudCol:0xb8c4d0,cloudOp:0.92, fogColor:0xa0b0c0,fogNear:25,fogFar:180, groundCol:0x3a5a30, ambCol:0xb8c4d0,ambInt:0.52, sunCol:0xd0dce8,sunInt:0.95,sunPos:[60,100,30], fillCol:0x90a0b0,fillInt:0.38, hemisSky:0x98a8b8,hemisGnd:0x3a5a30,hemisInt:0.44, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.usDay, skylineWin:[0x778899,0x99aabb,0x556677,0xaabbcc,0x667788], treeColor:0x2a5a28,treeTrunk:0x4a3018, previewGrad:['#98a8b8','#d0dce8','#3a5a30'], cityLights:[] },
  mexicoDust: { isDay:true,isSunset:false,isNight:false, sky:0x9ac8e8,cloudCol:0xfff8f0,cloudOp:0.55, fogColor:0xd8c8a8,fogNear:70,fogFar:320, groundCol:0x8a9a48, ambCol:0xfff0d8,ambInt:0.72, sunCol:0xffe0a0,sunInt:2.5,sunPos:[130,170,50], fillCol:0xffcc88,fillInt:0.48, hemisSky:0x9ac8e8,hemisGnd:0x8a9a48,hemisInt:0.46, curbA:0xff4400,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0xffaa44,0xff8844,0xddcc66,0xff6644,0xccaa55], treeColor:0x4a7020,treeTrunk:0x6a4018, previewGrad:['#9ac8e8','#ffe0a0','#8a9a48'], cityLights:[] },
  zurichAlpine: { isDay:true,isSunset:false,isNight:false, sky:0x78b8e8,cloudCol:0xffffff,cloudOp:0.8, fogColor:0xc0dff5,fogNear:90,fogFar:380, groundCol:0x4a8a38, ambCol:0xf0f8ff,ambInt:0.78, sunCol:0xfff8e8,sunInt:2.4,sunPos:[90,200,70], fillCol:0xa8d0ff,fillInt:0.52, hemisSky:0x78b8e8,hemisGnd:0x4a8a38,hemisInt:0.5, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.euro, skylineWin:[0x5599ff,0x88bbdd,0xaaccff,0x667799,0x99ccee], treeColor:0x2a7a28,treeTrunk:0x5a3818, previewGrad:['#78b8e8','#f0f8ff','#4a8a38'], cityLights:[] },
  hongKongNeon: { isDay:false,isSunset:false,isNight:true, sky:0x040810,fogColor:0x040810,fogNear:0,fogFar:0, groundCol:0x0c1018, ambCol:0x1a2844,ambInt:0.46, sunCol:0x99ccff,sunInt:0.38,sunPos:[45,110,55], fillCol:0x0088ff,fillInt:0.32, hemisSky:0x1a2844,hemisGnd:0x060810,hemisInt:0.3, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.neon, skylineWin:[0x0088ff,0xff0044,0x00ffcc,0xffcc00,0x8844ff], treeColor:0x0a220a,treeTrunk:0x2a1200, previewGrad:['#040810','#0088ff','#ff0044'], cityLights:[[0x0088ff,190],[0xff0044,200],[0x00ffcc,170]] },
  saigonTropical: { isDay:false,isSunset:true,isNight:false, sky:0xcc8866,cloudCol:0xffddbb,cloudOp:0.75, fogColor:0xb88870,fogNear:45,fogFar:240, groundCol:0x3a7a28, ambCol:0xffccaa,ambInt:0.58, sunCol:0xff8844,sunInt:1.5,sunPos:[180,60,20], fillCol:0xffaa66,fillInt:0.42, hemisSky:0xcc8866,hemisGnd:0x3a7a28,hemisInt:0.44, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0xff8844,0xffcc00,0x44aa66,0xff6644,0x88ccff], treeColor:0x1a6a18,treeTrunk:0x4a3010, previewGrad:['#cc8866','#ffccaa','#3a7a28'], cityLights:[] },
  sydneyHarbor: { isDay:false,isSunset:true,isNight:false, sky:0xf08040,cloudCol:0xffd8b0,cloudOp:0.7, fogColor:0xe89060,fogNear:70,fogFar:300, groundCol:0x4a8a30, ambCol:0xffcc99,ambInt:0.62, sunCol:0xff7722,sunInt:1.7,sunPos:[220,45,15], fillCol:0xff9955,fillInt:0.45, hemisSky:0xf08040,hemisGnd:0x4a8a30,hemisInt:0.48, curbA:0xff3311,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0xff8844,0x44aaff,0xffcc00,0x33cc88,0xff6644], treeColor:0x2a7a20,treeTrunk:0x5a3810, previewGrad:['#f08040','#ffd8b0','#4a8a30'], cityLights:[] },
  moscowFog: { isDay:false,isSunset:false,isNight:false, sky:0x8898a8,cloudCol:0xb0bcc8,cloudOp:0.9, fogColor:0x98a8b8,fogNear:20,fogFar:160, groundCol:0x4a5a40, ambCol:0xc0c8d0,ambInt:0.48, sunCol:0xd8e0e8,sunInt:0.9,sunPos:[50,90,30], fillCol:0x8898a8,fillInt:0.35, hemisSky:0x8898a8,hemisGnd:0x4a5a40,hemisInt:0.4, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.euro, skylineWin:[0x8899aa,0xcc4444,0x99aabb,0x667788,0xaabbcc], treeColor:0x2a4a20,treeTrunk:0x3a2818, previewGrad:['#8898a8','#d8e0e8','#4a5a40'], cityLights:[] },
  berlinDay: { isDay:true,isSunset:false,isNight:false, sky:0x72b0e8,cloudCol:0xffffff,cloudOp:0.75, fogColor:0xc0ddf5,fogNear:85,fogFar:400, groundCol:0x4a7a32, ambCol:0xfff8f0,ambInt:0.74, sunCol:0xfff0d0,sunInt:2.5,sunPos:[110,190,60], fillCol:0xa8d0ff,fillInt:0.5, hemisSky:0x72b0e8,hemisGnd:0x4a7a32,hemisInt:0.48, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.euro, skylineWin:[0x5599ff,0xffcc44,0x88bbdd,0xff6644,0x99ccee], treeColor:0x2d7a20,treeTrunk:0x5a3818, previewGrad:['#72b0e8','#fff0d0','#4a7a32'], cityLights:[] },
  parisGolden: { isDay:false,isSunset:true,isNight:false, sky:0xe8a060,cloudCol:0xffe0c0,cloudOp:0.72, fogColor:0xd89868,fogNear:55,fogFar:260, groundCol:0x5a8a38, ambCol:0xffddbb,ambInt:0.6, sunCol:0xffaa44,sunInt:1.65,sunPos:[200,55,25], fillCol:0xffcc88,fillInt:0.44, hemisSky:0xe8a060,hemisGnd:0x5a8a38,hemisInt:0.46, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.euro, skylineWin:[0xffcc66,0x88aadd,0xff8844,0xccaa88,0xffaa44], treeColor:0x3a6a28,treeTrunk:0x5a3818, previewGrad:['#e8a060','#ffe0c0','#5a8a38'], cityLights:[] },
  cairoSand: { isDay:true,isSunset:false,isNight:false, sky:0xa8d0f0,cloudCol:0xfff8f0,cloudOp:0.4, fogColor:0xe8d8b8,fogNear:100,fogFar:420, groundCol:0xc8b060, ambCol:0xfff4e0,ambInt:0.76, sunCol:0xffe8a8,sunInt:2.85,sunPos:[150,200,30], fillCol:0xffdd99,fillInt:0.52, hemisSky:0xa8d0f0,hemisGnd:0xc8b060,hemisInt:0.45, curbA:0xff4400,curbB:0xffffff, bldConfigs:KRC_BLD.gulf, skylineWin:[0xffcc66,0xffaa44,0xdd9944,0xff8844,0xeecc88], treeColor:0x5a7020,treeTrunk:0x7a5018, previewGrad:['#a8d0f0','#ffe8a8','#c8b060'], cityLights:[] },
  lagosHumid: { isDay:false,isSunset:false,isNight:false, sky:0x88a8c8,cloudCol:0xb0c8d8,cloudOp:0.82, fogColor:0x90a8c0,fogNear:40,fogFar:230, groundCol:0x3a7a28, ambCol:0xc8d8e8,ambInt:0.58, sunCol:0xffcc88,sunInt:1.4,sunPos:[120,100,40], fillCol:0x88bbdd,fillInt:0.42, hemisSky:0x88a8c8,hemisGnd:0x3a7a28,hemisInt:0.44, curbA:0xff3311,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0x44aaff,0xffcc44,0x33cc88,0xff6644,0x88ddff], treeColor:0x1a6a18,treeTrunk:0x4a3010, previewGrad:['#88a8c8','#c8d8e8','#3a7a28'], cityLights:[] },
  seoulNeon: { isDay:false,isSunset:false,isNight:true, sky:0x03050c,fogColor:0x03050c,fogNear:0,fogFar:0, groundCol:0x0c0e16, ambCol:0x182844,ambInt:0.46, sunCol:0x99bbff,sunInt:0.36,sunPos:[42,115,58], fillCol:0x00aaff,fillInt:0.32, hemisSky:0x182844,hemisGnd:0x060810,hemisInt:0.3, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.neon, skylineWin:[0x00aaff,0xff00aa,0x00ffcc,0xffcc00,0x8844ff], treeColor:0x0a220a,treeTrunk:0x2a1200, previewGrad:['#03050c','#00aaff','#ff00aa'], cityLights:[[0x00aaff,185],[0xff00aa,195],[0x00ffcc,175]] },
  mumbaiMonsoon: { isDay:false,isSunset:false,isNight:false, sky:0x788898,cloudCol:0x98a8b8,cloudOp:0.92, fogColor:0x8090a0,fogNear:35,fogFar:200, groundCol:0x3a6a30, ambCol:0xb0c0c8,ambInt:0.54, sunCol:0xd0dce8,sunInt:1.0,sunPos:[70,110,45], fillCol:0x8899aa,fillInt:0.4, hemisSky:0x788898,hemisGnd:0x3a6a30,hemisInt:0.44, curbA:0xcc1100,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0x88aabb,0xffaa44,0x66aa88,0x99bbcc,0x778899], treeColor:0x2a6a22,treeTrunk:0x4a3018, previewGrad:['#788898','#b0c0c8','#3a6a30'], cityLights:[] },
  johannesburgDusk: { isDay:false,isSunset:true,isNight:false, sky:0xd87838,cloudCol:0xffc8a0,cloudOp:0.68, fogColor:0xc86840,fogNear:55,fogFar:270, groundCol:0x6a8a38, ambCol:0xffbb88,ambInt:0.58, sunCol:0xff6622,sunInt:1.55,sunPos:[210,50,20], fillCol:0xff8844,fillInt:0.42, hemisSky:0xd87838,hemisGnd:0x6a8a38,hemisInt:0.45, curbA:0xff4400,curbB:0xffffff, bldConfigs:KRC_BLD.usDay, skylineWin:[0xff8844,0xffcc44,0x88aa44,0xff6644,0xddaa55], treeColor:0x3a6a20,treeTrunk:0x5a3818, previewGrad:['#d87838','#ffc8a0','#6a8a38'], cityLights:[] },
  aucklandCoast: { isDay:true,isSunset:false,isNight:false, sky:0x68b8e8,cloudCol:0xffffff,cloudOp:0.82, fogColor:0xb8e0f8,fogNear:95,fogFar:410, groundCol:0x4a9a38, ambCol:0xf0faff,ambInt:0.76, sunCol:0xfff4d8,sunInt:2.4,sunPos:[100,185,65], fillCol:0x98d8ff,fillInt:0.52, hemisSky:0x68b8e8,hemisGnd:0x4a9a38,hemisInt:0.5, curbA:0xff3311,curbB:0xffffff, bldConfigs:KRC_BLD.tropical, skylineWin:[0x44aaff,0x88ddff,0x33cc88,0xffaa44,0x66bbff], treeColor:0x2a7a22,treeTrunk:0x5a4010, previewGrad:['#68b8e8','#f0faff','#4a9a38'], cityLights:[] }
};

const CITY_META = [
  ['NEW YORK','United States','Midtown grid · neon nights','nycNight'],
  ['TOKYO','Japan','Shibuya lights · tight streets','tokyoNeon'],
  ['DUBAI','United Arab Emirates','Desert towers · golden heat','dubaiSunset'],
  ['LONDON','United Kingdom','River bends · grey rain','londonRain'],
  ['LOS ANGELES','United States','Pacific coast · palm highways','laDay'],
  ['MIAMI','United States','Ocean drive · art-deco glow','miamiNeon'],
  ['SAN FRANCISCO','United States','Bay bridges · steep grades','laDay'],
  ['RIO DE JANEIRO','Brazil','Harbor curves · tropical hills','rioTropical'],
  ['LAS VEGAS','United States','Casino strip · desert night','vegasNight'],
  ['CHICAGO','United States','Lakefront industry · dusk fog','chicagoFog'],
  ['WASHINGTON, D.C.','United States','Monument avenues · clear grid','laDay'],
  ['DUBLIN','Ireland','Coastal rain · rolling lanes','dublinRain'],
  ['HONOLULU','United States','Island ring · volcanic coast','honoluluTropical'],
  ['DETROIT','United States','Factory skyline · night haze','detroitNight'],
  ['PHOENIX','United States','Canyon heat · red dust','phoenixDesert'],
  ['SEATTLE','United States','Puget mist · wet asphalt','seattleFog'],
  ['MEXICO CITY','Mexico','High plateau · dusty avenues','mexicoDust'],
  ['ZURICH','Switzerland','Mountain pass · crisp air','zurichAlpine'],
  ['HONG KONG','China','Victoria Harbour · neon rain','hongKongNeon'],
  ['HO CHI MINH CITY','Vietnam','River delta · scooter flow','saigonTropical'],
  ['SYDNEY','Australia','Opera coast · golden hour','sydneyHarbor'],
  ['MOSCOW','Russia','Wide boulevards · winter fog','moscowFog'],
  ['BERLIN','Germany','Spree banks · modern grid','berlinDay'],
  ['PARIS','France','Seine curves · limestone glow','parisGolden'],
  ['CAIRO','Egypt','Nile edge · desert sun','cairoSand'],
  ['LAGOS','Nigeria','Atlantic coast · humid streets','lagosHumid'],
  ['SEOUL','South Korea','Gangnam grid · electric night','seoulNeon'],
  ['MUMBAI','India','Monsoon lanes · dense traffic','mumbaiMonsoon'],
  ['JOHANNESBURG','South Africa','Highveld ridges · gold dusk','johannesburgDusk'],
  ['AUCKLAND','New Zealand','Waitematā breeze · harbours','aucklandCoast']
];

const snippet = `// 30 real-world cities (index order matches iOS CityThemeID)
const CITY_DEFS = ${JSON.stringify(CITY_META.map(m => Object.assign({}, T[m[3]], { name: m[0], country: m[1], desc: m[2] })), null, 2).replace(/"(\w+)":/g, '$1:')};
`;

function patchHtml(file) {
  let html = fs.readFileSync(file, 'utf8');
  const start = html.indexOf('// ── City Definitions');
  const end = html.indexOf('let selectedCityIdx = 0;');
  if (start < 0 || end < 0) throw new Error('markers not found in ' + file);
  const replacement = snippet + '\nlet cityPts = [];\n';
  html = html.slice(0, start) + replacement + html.slice(end + 'let cityPts = [];'.length);
  if (!html.includes("city.country + ' · '")) {
    html = html.replace(
      "'<motion class=\"city-card-desc\">' + city.desc + '</motion>",
      "'<div class=\"city-card-desc\">' + city.country + ' · ' + city.desc + '</div>"
    );
    html = html.replace(
      "'<motion class=\"city-card-desc\">' + city.desc + '</div>'",
      "'<motion class=\"city-card-desc\">' + city.country + ' · ' + city.desc + '</div>'"
    );
  }
  html = html.replace(
    /'<div class="city-card-desc">' \+ city\.desc \+ '<\/motion>/,
    "'<motion class=\"city-card-desc\">' + city.country + ' · ' + city.desc + '</div>"
  );
  // fix buildCityGrid desc line
  html = html.replace(
    "'<motion class=\"city-card-desc\">' + city.desc + '</motion>",
    "'<div class=\"city-card-desc\">' + city.country + ' · ' + city.desc + '</motion>"
  );
  const gridLine = "      '<motion class=\"city-card-desc\">' + city.desc + '</div>';";
  const gridLineFixed = "      '<div class=\"city-card-desc\">' + city.country + ' · ' + city.desc + '</motion>';";
  if (html.includes("city.desc + '</motion>")) {
    html = html.replace(/'<div class="city-card-desc">' \+ city\.desc \+ '<\/div>';/g,
      "'<div class=\"city-card-desc\">' + city.country + ' · ' + city.desc + '</div>';");
  }
  fs.writeFileSync(file, html);
}

const root = path.join(__dirname, '..');
patchHtml(path.join(root, 'index.html'));
patchHtml(path.join(root, 'ios/KadenRacing/WebBundle/index.html'));
console.log('Patched index.html and WebBundle');
