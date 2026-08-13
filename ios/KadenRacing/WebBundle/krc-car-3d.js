/**
 * Shared Three.js car preview (garage + car select). No 2D PNG/SVG art.
 */
(function (global) {
  'use strict';

  var GLB_URL = 'models/cars/krc-camber-ss.glb';
  var instances = new WeakMap();
  var gltfLoader = null;
  var glbTemplate = null;

  function getLoader() {
    if (!global.THREE || !global.THREE.GLTFLoader) return null;
    if (!gltfLoader) gltfLoader = new global.THREE.GLTFLoader();
    return gltfLoader;
  }

  function ensureLights(scene) {
    if (scene.userData.lit) return;
    var amb = new global.THREE.AmbientLight(0xffffff, 0.55);
    var key = new global.THREE.DirectionalLight(0xffffff, 0.95);
    key.position.set(4, 8, 6);
    var rim = new global.THREE.DirectionalLight(0x00d4ff, 0.35);
    rim.position.set(-5, 3, -4);
    scene.add(amb, key, rim);
    scene.userData.lit = true;
  }

  function tintModel(root, bodyHex) {
    root.traverse(function (o) {
      if (!o.isMesh || !o.material) return;
      var mats = Array.isArray(o.material) ? o.material : [o.material];
      mats.forEach(function (m) {
        if (!m) return;
        var n = ((m.name || '') + ' ' + (o.name || '')).toLowerCase();
        if (/glass|window|tire|wheel|brake|light|rim|spoke|rubber/.test(n)) return;
        if (/body|paint|helga|shell|exterior/.test(n) && m.color) {
          m.color.setHex(bodyHex);
          if (m.metalness !== undefined) m.metalness = 0.45;
          if (m.roughness !== undefined) m.roughness = 0.38;
        }
      });
    });
  }

  function fitModel(model) {
    var box = new global.THREE.Box3().setFromObject(model);
    var size = new global.THREE.Vector3();
    box.getSize(size);
    var s = 3.6 / Math.max(size.x, size.y, size.z, 0.001);
    model.scale.setScalar(s);
    box.setFromObject(model);
    var center = new global.THREE.Vector3();
    box.getCenter(center);
    model.position.sub(center);
    model.position.y += 0.2;
  }

  function plateLabel(carId, carName) {
    if (carId === 'police') return 'POLICE';
    if (!carName) return 'KRC';
    return carName.indexOf('KRC ') === 0 ? carName.slice(4) : carName;
  }

  function drawLicensePlateCanvas(g, w, h, text, dark) {
    text = (text || 'KRC').toUpperCase();
    var outer = { x: 6, y: 6, w: w - 12, h: h - 12 };
    var inner = { x: outer.x + 14, y: outer.y + 14, w: outer.w - 28, h: outer.h - 28 };

    g.save();
    roundRect(g, outer.x, outer.y, outer.w, outer.h, 22);
    g.clip();
    var frameGrad = g.createLinearGradient(outer.x, outer.y, outer.x + outer.w, outer.y + outer.h);
    if (dark) {
      frameGrad.addColorStop(0, '#52565c');
      frameGrad.addColorStop(1, '#242629');
    } else {
      frameGrad.addColorStop(0, '#e0e2e6');
      frameGrad.addColorStop(1, '#94989e');
    }
    g.fillStyle = frameGrad;
    g.fillRect(outer.x, outer.y, outer.w, outer.h);
    g.restore();

    g.save();
    roundRect(g, inner.x, inner.y, inner.w, inner.h, 16);
    g.clip();
    if (dark) {
      g.fillStyle = '#0d111c';
      g.fillRect(inner.x, inner.y, inner.w, inner.h);
    } else {
      var faceGrad = g.createLinearGradient(inner.x, inner.y, inner.x, inner.y + inner.h);
      faceGrad.addColorStop(0, '#fcfcff');
      faceGrad.addColorStop(0.55, '#e8eaee');
      faceGrad.addColorStop(1, '#f5f6f8');
      g.fillStyle = faceGrad;
      g.fillRect(inner.x, inner.y, inner.w, inner.h);
    }
    g.fillStyle = dark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.22)';
    roundRect(g, inner.x + inner.w * 0.08, inner.y + inner.h * 0.12, inner.w * 0.84, inner.h * 0.18, 8);
    g.fill();
    g.restore();

    g.strokeStyle = dark ? 'rgba(90,95,105,0.9)' : 'rgba(180,185,195,0.9)';
    g.lineWidth = 2;
    roundRect(g, inner.x, inner.y, inner.w, inner.h, 16);
    g.stroke();

    drawPlateBolts(g, inner, dark);

    var headerH = inner.h * 0.22;
    var hx = inner.x + 10;
    var hy = inner.y + 8;
    var hw = inner.w - 20;
    g.fillStyle = dark ? '#1e2438' : '#143a85';
    roundRect(g, hx, hy, hw, headerH, 6);
    g.fill();
    if (dark) {
      g.fillStyle = '#d91f2e';
      g.fillRect(hx, hy + headerH - 3, hw, 3);
      g.fillStyle = '#1f5aeb';
      g.fillRect(hx, hy + headerH - 6, hw * 0.48, 3);
    }
    g.fillStyle = '#f5f7fa';
    g.font = 'bold 22px Arial, Helvetica, sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText(dark ? 'EMERGENCY' : 'KRC', hx + hw / 2, hy + headerH / 2);

    var lines = [];
    if (text.length > 14 && text.indexOf(' ') >= 0) {
      var sp = text.indexOf(' ');
      lines.push(text.slice(0, sp), text.slice(sp + 1));
    } else if (text.length > 16) {
      var mid = Math.floor(text.length / 2);
      lines.push(text.slice(0, mid), text.slice(mid));
    } else {
      lines.push(text);
    }
    var fontSize = lines.length > 1 ? 38 : (text.length > 12 ? 40 : 48);
    g.font = '900 ' + fontSize + 'px Arial Black, Impact, sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    var textTop = hy + headerH + 6;
    var textH = inner.y + inner.h - textTop - 10;
    var lineH = fontSize * 1.15;
    var startY = textTop + textH / 2 - ((lines.length - 1) * lineH) / 2;
    lines.forEach(function (line, i) {
      var ty = startY + i * lineH;
      g.fillStyle = dark ? 'rgba(0,0,0,0.55)' : 'rgba(255,255,255,0.85)';
      g.fillText(line, hx + hw / 2, ty + (dark ? 2.5 : -2.5));
      g.strokeStyle = dark ? 'rgba(0,0,0,0.65)' : 'rgba(0,0,0,0.9)';
      g.lineWidth = 3;
      g.strokeText(line, hx + hw / 2, ty);
      g.fillStyle = dark ? '#eef1f8' : '#0a0c12';
      g.fillText(line, hx + hw / 2, ty);
    });
  }

  function roundRect(g, x, y, w, h, r) {
    g.beginPath();
    g.moveTo(x + r, y);
    g.lineTo(x + w - r, y);
    g.quadraticCurveTo(x + w, y, x + w, y + r);
    g.lineTo(x + w, y + h - r);
    g.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    g.lineTo(x + r, y + h);
    g.quadraticCurveTo(x, y + h, x, y + h - r);
    g.lineTo(x, y + r);
    g.quadraticCurveTo(x, y, x + r, y);
    g.closePath();
  }

  function drawPlateBolts(g, inner, dark) {
    var inset = 18;
    var r = 5;
    var pts = [
      [inner.x + inset, inner.y + inset],
      [inner.x + inner.w - inset, inner.y + inset],
      [inner.x + inset, inner.y + inner.h - inset],
      [inner.x + inner.w - inset, inner.y + inner.h - inset]
    ];
    pts.forEach(function (p) {
      g.beginPath();
      g.arc(p[0], p[1], r, 0, Math.PI * 2);
      g.fillStyle = dark ? '#474b52' : '#8c9098';
      g.fill();
      g.strokeStyle = dark ? '#1e2024' : '#52565c';
      g.lineWidth = 1.2;
      g.stroke();
      g.beginPath();
      g.arc(p[0], p[1], 1.5, 0, Math.PI * 2);
      g.fillStyle = dark ? 'rgba(170,175,185,0.55)' : 'rgba(255,255,255,0.75)';
      g.fill();
    });
  }

  function makeLicensePlate(text, pw, ph, dark) {
    var c = document.createElement('canvas');
    c.width = 1024;
    c.height = 360;
    drawLicensePlateCanvas(c.getContext('2d'), c.width, c.height, text, dark);
    var tex = new global.THREE.CanvasTexture(c);
    tex.anisotropy = 4;
    tex.colorSpace = global.THREE.SRGBColorSpace || undefined;

    var group = new global.THREE.Group();
    var frameGeo = new global.THREE.BoxGeometry(pw * 1.04, ph * 1.06, pw * 0.018);
    var frameMat = new global.THREE.MeshStandardMaterial({
      color: dark ? 0x3a3e44 : 0xb8bcc2,
      metalness: 0.88,
      roughness: 0.24
    });
    group.add(new global.THREE.Mesh(frameGeo, frameMat));

    var faceMat = new global.THREE.MeshStandardMaterial({
      map: tex,
      metalness: dark ? 0.42 : 0.28,
      roughness: 0.18,
      transparent: false,
      side: global.THREE.DoubleSide
    });
    var face = new global.THREE.Mesh(new global.THREE.PlaneGeometry(pw, ph), faceMat);
    face.position.z = pw * 0.011;
    face.renderOrder = 121;
    group.add(face);
    group.renderOrder = 120;
    return group;
  }

  function attachRearPlate(model, carId, carName) {
    model.children.filter(function (c) { return c.name === 'krcLicensePlate'; }).forEach(function (c) { model.remove(c); });
    var box = new global.THREE.Box3().setFromObject(model);
    var size = new global.THREE.Vector3();
    box.getSize(size);
    var rearIsMinZ = box.min.z < box.max.z;
    var flushInset = size.z * 0.006;
    var rearZ = rearIsMinZ ? box.min.z + flushInset : box.max.z - flushInset;
    var y = box.min.y + size.y * 0.40;
    var pw = Math.max(size.x * 0.30, 0.68);
    var plate = makeLicensePlate(plateLabel(carId, carName), pw * (carId === 'police' ? 0.85 : 1), pw * 0.28, carId === 'police');
    plate.name = 'krcLicensePlate';
    plate.position.set(0, y, rearZ);
    plate.rotation.y = rearIsMinZ ? Math.PI : 0;
    model.add(plate);
  }

  function attachPoliceKit(model) {
    model.children.filter(function (c) { return c.name === 'krcPoliceKit'; }).forEach(function (c) { model.remove(c); });
    var box = new global.THREE.Box3().setFromObject(model);
    var size = new global.THREE.Vector3();
    box.getSize(size);
    var kit = new global.THREE.Group();
    kit.name = 'krcPoliceKit';
    var bar = new global.THREE.Mesh(
      new global.THREE.BoxGeometry(1.55, 0.09, 0.22),
      new global.THREE.MeshBasicMaterial({ color: 0x121820 })
    );
    bar.position.set(0, box.min.y + size.y * 0.88, box.min.z + size.z * 0.52);
    kit.add(bar);
    [[-0.18, 0xff1028], [0.18, 0x147cff]].forEach(function (pair) {
      var lens = new global.THREE.Mesh(
        new global.THREE.BoxGeometry(0.28, 0.07, 0.18),
        new global.THREE.MeshBasicMaterial({ color: pair[1] })
      );
      lens.position.set(pair[0], bar.position.y + 0.04, bar.position.z);
      kit.add(lens);
    });
    model.add(kit);
  }

  function applyCarVisuals(model, carId, carName) {
    if (!model) return;
    if (carId === 'police') attachPoliceKit(model);
    attachRearPlate(model, carId, carName);
  }

  function proceduralCar(bodyHex) {
    var g = new global.THREE.Group();
    var body = new global.THREE.Mesh(
      new global.THREE.BoxGeometry(1.9, 0.45, 4.0),
      new global.THREE.MeshStandardMaterial({ color: bodyHex, metalness: 0.55, roughness: 0.35 })
    );
    body.position.y = 0.35;
    g.add(body);
    var cabin = new global.THREE.Mesh(
      new global.THREE.BoxGeometry(1.2, 0.35, 1.1),
      new global.THREE.MeshStandardMaterial({
        color: 0x9fc8ff,
        metalness: 0.2,
        roughness: 0.1,
        transparent: true,
        opacity: 0.45
      })
    );
    cabin.position.set(0, 0.72, -0.2);
    g.add(cabin);
    return g;
  }

  function loadGlbTemplate(done) {
    if (glbTemplate) {
      done(glbTemplate.clone(true));
      return;
    }
    var loader = getLoader();
    if (!loader) {
      done(null);
      return;
    }
    loader.load(
      GLB_URL,
      function (gltf) {
        glbTemplate = gltf.scene;
        done(gltf.scene.clone(true));
      },
      undefined,
      function () {
        done(null);
      }
    );
  }

  function mount(canvas, carId, bodyHex, carName) {
    if (!global.THREE || !canvas) return { destroy: function () {} };

    var prev = instances.get(canvas);
    if (prev) prev.destroy();

    var width = Math.max(160, canvas.clientWidth || 280);
    var height = Math.max(120, canvas.clientHeight || 160);
    var renderer = new global.THREE.WebGLRenderer({ canvas: canvas, alpha: true, antialias: true });
    renderer.setPixelRatio(Math.min(global.devicePixelRatio || 1, 2));
    renderer.setSize(width, height, false);

    var scene = new global.THREE.Scene();
    ensureLights(scene);
    var camera = new global.THREE.PerspectiveCamera(34, width / height, 0.1, 100);
    camera.position.set(0, 1.35, 5.2);
    camera.lookAt(0, 0.35, 0);

    var carRoot = new global.THREE.Group();
    scene.add(carRoot);

    loadGlbTemplate(function (model) {
      if (!instances.get(canvas)) return;
      if (model) {
        tintModel(model, bodyHex);
        fitModel(model);
        carRoot.add(model);
        applyCarVisuals(model, carId || 'f40', carName || '');
        carRoot.rotation.y = 0.52 * Math.PI;
      } else {
        carRoot.add(proceduralCar(bodyHex));
      }
    });

    var state = { alive: true, t: 0 };
    function frame() {
      if (!state.alive) return;
      state.t += 0.016;
      carRoot.rotation.y += 0.012;
      renderer.render(scene, camera);
      state.raf = global.requestAnimationFrame(frame);
    }
    frame();

    var api = {
      destroy: function () {
        state.alive = false;
        if (state.raf) global.cancelAnimationFrame(state.raf);
        renderer.dispose();
        instances.delete(canvas);
      },
      resize: function () {
        var w = Math.max(160, canvas.clientWidth || 280);
        var h = Math.max(120, canvas.clientHeight || 160);
        renderer.setSize(w, h, false);
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
      }
    };
    instances.set(canvas, api);
    return api;
  }

  function mountMenuDriveIn(canvas, carId, bodyHex, carName, opts) {
    opts = opts || {};
    if (!global.THREE || !canvas) return { destroy: function () {} };

    var prev = instances.get(canvas);
    if (prev) prev.destroy();

    var width = Math.max(200, canvas.clientWidth || 360);
    var height = Math.max(88, canvas.clientHeight || 112);
    var renderer = new global.THREE.WebGLRenderer({ canvas: canvas, alpha: true, antialias: true });
    renderer.setPixelRatio(Math.min(global.devicePixelRatio || 1, 2));
    renderer.setSize(width, height, false);

    var scene = new global.THREE.Scene();
    ensureLights(scene);
    var camera = new global.THREE.PerspectiveCamera(32, width / height, 0.1, 100);
    camera.position.set(0.15, 0.72, 4.35);
    camera.lookAt(-0.05, 0.28, 0);

    var carRoot = new global.THREE.Group();
    scene.add(carRoot);
    var wheelSpinners = [];

    loadGlbTemplate(function (model) {
      if (!instances.get(canvas)) return;
      if (model) {
        tintModel(model, bodyHex);
        fitModel(model);
        carRoot.add(model);
        applyCarVisuals(model, carId || 'f40', carName || '');
        carRoot.rotation.y = -0.5 * Math.PI;
        model.traverse(function (o) {
          var n = (o.name || '').toLowerCase();
          if (/wheel|tire|rim/.test(n) && o.isMesh) wheelSpinners.push(o);
        });
      } else {
        carRoot.add(proceduralCar(bodyHex));
      }
      carRoot.position.x = -5.4;
      startDrive();
    });

    var state = {
      alive: true,
      driving: false,
      revving: false,
      bob: 0,
      driveStart: 0,
      driveDur: 1080
    };

    function easeOutCubic(t) {
      return 1 - Math.pow(1 - t, 3);
    }

    function startDrive() {
      state.driving = true;
      state.driveStart = performance.now();
    }

    function frame(now) {
      if (!state.alive) return;

      if (state.driving) {
        var t = Math.min(1, (now - state.driveStart) / state.driveDur);
        var e = easeOutCubic(t);
        carRoot.position.x = -5.4 + e * 5.4;
        wheelSpinners.forEach(function (w) {
          w.rotation.x -= 0.2;
        });
        if (t >= 1) {
          state.driving = false;
          state.revving = true;
          state.revUntil = now + 760;
          if (typeof opts.onDriveComplete === 'function') opts.onDriveComplete();
        }
      } else if (state.revving) {
        state.bob += 0.14;
        carRoot.rotation.z = Math.sin(state.bob) * 0.018;
        wheelSpinners.forEach(function (w) {
          w.rotation.x -= 0.07;
        });
        if (now > state.revUntil) state.revving = false;
      }

      renderer.render(scene, camera);
      state.raf = global.requestAnimationFrame(frame);
    }
    frame(performance.now());

    var api = {
      destroy: function () {
        state.alive = false;
        if (state.raf) global.cancelAnimationFrame(state.raf);
        renderer.dispose();
        instances.delete(canvas);
      },
      resize: function () {
        var w = Math.max(200, canvas.clientWidth || 360);
        var h = Math.max(88, canvas.clientHeight || 112);
        renderer.setSize(w, h, false);
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
      }
    };
    instances.set(canvas, api);
    return api;
  }

  global.KRCCarPreview = { mount: mount, mountMenuDriveIn: mountMenuDriveIn };
  global.KRCLicensePlate = { drawCanvas: drawLicensePlateCanvas, makeMesh: makeLicensePlate };
})(typeof window !== 'undefined' ? window : globalThis);
