const form = document.getElementById("convert-form");
const dropzone = document.getElementById("dropzone");
const pathField = document.getElementById("path-field");
const networkPath = document.getElementById("network-path");
const fileInput = document.getElementById("file-input");
const fileChip = document.getElementById("file-chip");
const statusEl = document.getElementById("status");
const convertBtn = document.getElementById("convert-btn");
const resultEl = document.getElementById("result");
const statsEl = document.getElementById("stats");
const layersEl = document.getElementById("layers");
const messagesEl = document.getElementById("messages");
const downloadLink = document.getElementById("download-link");
const tabUpload = document.getElementById("tab-upload");
const tabPath = document.getElementById("tab-path");

let sourceMode = "upload";

function setStatus(text, isError = false) {
  statusEl.textContent = text;
  statusEl.classList.toggle("error", isError);
}

function showFileName(file) {
  if (!file) {
    fileChip.hidden = true;
    fileChip.textContent = "";
    return;
  }
  const sizeKb = Math.max(1, Math.round(file.size / 1024));
  fileChip.hidden = false;
  fileChip.textContent = `${file.name} · ${sizeKb} KB`;
}

function setSourceMode(mode) {
  sourceMode = mode;
  tabUpload.classList.toggle("active", mode === "upload");
  tabPath.classList.toggle("active", mode === "path");
  dropzone.hidden = mode !== "upload";
  pathField.hidden = mode !== "path";
  fileInput.required = mode === "upload";
}

tabUpload.addEventListener("click", () => setSourceMode("upload"));
tabPath.addEventListener("click", () => setSourceMode("path"));

["dragenter", "dragover"].forEach((eventName) => {
  dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    dropzone.classList.add("dragover");
  });
});

["dragleave", "drop"].forEach((eventName) => {
  dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    dropzone.classList.remove("dragover");
  });
});

dropzone.addEventListener("drop", (event) => {
  const files = event.dataTransfer?.files;
  if (files && files.length) {
    fileInput.files = files;
    showFileName(files[0]);
  }
});

fileInput.addEventListener("change", () => {
  showFileName(fileInput.files?.[0]);
});

function commonOptions() {
  return {
    dxf_version: document.getElementById("dxf_version").value,
    explode_blocks: document.getElementById("explode_blocks").checked,
    convert_splines: document.getElementById("convert_splines").checked,
    explode_proxies: document.getElementById("explode_proxies").checked,
    include_display_only: document.getElementById("include_display_only").checked,
    flatten_z: document.getElementById("flatten_z").checked,
    include_layers: document.getElementById("include_layers").value.trim(),
    exclude_layers: document.getElementById("exclude_layers").value.trim(),
  };
}

function renderResult(payload) {
  resultEl.hidden = false;
  downloadLink.href = payload.download_url;
  downloadLink.download = payload.output_name || "trimble_access.dxf";

  const items = [
    ["Stakeable entities", payload.stakeable_count],
    ["Proxies exploded", payload.proxy_carriers_exploded ?? 0],
    ["Proxy primitives", payload.proxy_primitives_created ?? 0],
    ["DXF version", payload.dxf_version],
    ["DWG engine", payload.engine],
  ];

  statsEl.innerHTML = items
    .map(
      ([label, value]) => `
      <div>
        <dt>${label}</dt>
        <dd>${value ?? "—"}</dd>
      </div>`
    )
    .join("");

  layersEl.innerHTML = (payload.layers || [])
    .map(
      (layer) =>
        `<span class="layer-pill">${layer.name} · ${layer.stakeable_count} stakeable</span>`
    )
    .join("");

  const notes = [...(payload.messages || []), ...(payload.warnings || [])];
  messagesEl.innerHTML = notes.map((note) => `<li>${note}</li>`).join("");
  resultEl.scrollIntoView({ behavior: "smooth", block: "nearest" });
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const options = commonOptions();

  convertBtn.disabled = true;
  resultEl.hidden = true;
  setStatus("Converting linework for Trimble Access…");

  try {
    let response;
    if (sourceMode === "path") {
      const path = networkPath.value.trim();
      if (!path) {
        throw new Error("Enter a network or mounted DWG/DXF path.");
      }
      response = await fetch("/api/convert-path", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          path,
          dxf_version: options.dxf_version,
          explode_blocks: options.explode_blocks,
          convert_splines: options.convert_splines,
          explode_proxies: options.explode_proxies,
          include_display_only: options.include_display_only,
          flatten_z: options.flatten_z,
          include_layers: options.include_layers || null,
          exclude_layers: options.exclude_layers || null,
        }),
      });
    } else {
      const file = fileInput.files?.[0];
      if (!file) {
        throw new Error("Choose a DWG or DXF file first.");
      }
      const body = new FormData();
      body.append("file", file);
      body.append("dxf_version", options.dxf_version);
      body.append("explode_blocks", options.explode_blocks);
      body.append("convert_splines", options.convert_splines);
      body.append("explode_proxies", options.explode_proxies);
      body.append("include_display_only", options.include_display_only);
      body.append("flatten_z", options.flatten_z);
      if (options.include_layers) body.append("include_layers", options.include_layers);
      if (options.exclude_layers) body.append("exclude_layers", options.exclude_layers);
      response = await fetch("/api/convert", { method: "POST", body });
    }

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.detail || "Conversion failed.");
    }
    const proxyNote = payload.proxy_carriers_exploded
      ? ` Recovered ${payload.proxy_carriers_exploded} Civil 3D proxy object(s).`
      : "";
    setStatus(
      payload.stakeable_count
        ? `Converted ${payload.stakeable_count} stakeable entit${
            payload.stakeable_count === 1 ? "y" : "ies"
          }.${proxyNote}`
        : "Conversion finished — check warnings."
    );
    renderResult(payload);
  } catch (error) {
    setStatus(error.message || "Conversion failed.", true);
  } finally {
    convertBtn.disabled = false;
  }
});

fetch("/api/guide")
  .then((response) => (response.ok ? response.json() : null))
  .then((guide) => {
    if (!guide) return;
    const civil = document.getElementById("civil-steps");
    const trimble = document.getElementById("trimble-steps");
    if (civil && guide.civil3d_prep) {
      civil.innerHTML = guide.civil3d_prep.map((step) => `<li>${step}</li>`).join("");
    }
    if (trimble && guide.no_autocad_field_workflow) {
      trimble.innerHTML = guide.no_autocad_field_workflow
        .map((step) => `<li>${step}</li>`)
        .join("");
    } else if (trimble && guide.trimble_import) {
      trimble.innerHTML = guide.trimble_import.map((step) => `<li>${step}</li>`).join("");
    }
  })
  .catch(() => {});
