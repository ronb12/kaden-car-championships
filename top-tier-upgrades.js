(() => {
  const key = "kaden-racing-championships-race-director-v1";
  const state = JSON.parse(localStorage.getItem(key) || "null") || {
    license: "Club Racer",
    cornering: 28,
    nitro: 24,
    clean: 20,
    car: "Street Coupe",
    event: "Daily Sprint",
    club: "Solo Garage",
    drillCount: 0,
    lastAction: "Race school ready",
    syncStatus: "Local progress queue ready",
  };
  const cars = ["Street Coupe", "Turbo Rally", "Hyper GT", "Police Interceptor"];
  const events = ["Daily Sprint", "Career Cup", "Grand Prix", "Club Gauntlet"];
  const save = () => localStorage.setItem(key, JSON.stringify(state));
  const clamp = (value) => Math.max(0, Math.min(100, value));

  function license() {
    const total = state.cornering + state.nitro + state.clean;
    if (total >= 240) return "World Champion";
    if (total >= 165) return "Pro Circuit";
    if (total >= 100) return "Street Finalist";
    return "Club Racer";
  }

  function improve(field) {
    state[field] = clamp(state[field] + 12);
    state.drillCount = (state.drillCount || 0) + 1;
    state.license = license();
    const index = Math.min(cars.length - 1, Math.floor((state.cornering + state.nitro + state.clean) / 85));
    state.car = cars[index];
    state.event = events[index];
    state.club = index >= 2 ? "Kaden Racing Club" : "Solo Garage";
    state.lastAction = `${field.replace(/^\w/, (letter) => letter.toUpperCase())} drill logged #${state.drillCount}`;
    state.syncStatus = "Progress saved locally; backend contract ready for leaderboard/cloud sync";
    save();
    render();
  }

  function render() {
    let panel = document.querySelector("#raceDirector");
    if (!panel) {
      panel = document.createElement("aside");
      panel.id = "raceDirector";
      panel.className = "race-director";
      document.body.appendChild(panel);
    }
    panel.innerHTML = `
      <div class="race-director__head">
        <div>
          <h2>Race Director</h2>
          <p>Advanced driver progression for cleaner racing, stronger nitro timing, and mobile control polish.</p>
        </div>
        <span class="race-license">${state.license}</span>
      </div>
      <div class="race-director__grid">
        <button data-race="cornering"><span>Cornering</span><strong>${state.cornering}</strong></button>
        <button data-race="nitro"><span>Nitro</span><strong>${state.nitro}</strong></button>
        <button data-race="clean"><span>Clean Run</span><strong>${state.clean}</strong></button>
      </div>
      <div class="race-director__systems">
        <div><span>Garage</span><strong>${state.car}</strong></div>
        <div><span>Event</span><strong>${state.event}</strong></div>
        <div><span>Club</span><strong>${state.club}</strong></div>
        <div><span>Last Drill</span><strong>${state.lastAction || "Race school ready"}</strong></div>
        <div><span>Sync</span><strong>${state.syncStatus || "Local progress queue ready"}</strong></div>
      </div>
      <p class="race-director__note">Fallback renderer now keeps menus/progression alive if WebGL is blocked; full 3D racing resumes when WebGL is available.</p>
    `;
    panel.querySelectorAll("[data-race]").forEach((button) => {
      button.addEventListener("click", () => improve(button.dataset.race));
    });
  }

  render();
})();
