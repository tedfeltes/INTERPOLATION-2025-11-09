const form = document.getElementById("convert-form");
const dropzone = document.getElementById("dropzone");
const fileInput = document.getElementById("file-input");
const fileChip = document.getElementById("file-chip");
const statusEl = document.getElementById("status");
const convertBtn = document.getElementById("convert-btn");
const resultEl = document.getElementById("result");
const statsEl = document.getElementById("stats");
const layersEl = document.getElementById("layers");
const messagesEl = document.getElementById("messages");
const downloadLink = document.getElementById("download-link");

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

function renderResult(payload) {
  resultEl.hidden = false;
  downloadLink.href = payload.download_url;
  downloadLink.download = payload.output_name || "trimble_access.dxf";

  const items = [
    ["Stakeable entities", payload.stakeable_count],
    ["Output entities", payload.output_entity_count],
    ["Source entities", payload.source_entity_count],
    ["DXF version", payload.dxf_version],
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
  const file = fileInput.files?.[0];
  if (!file) {
    setStatus("Choose a DWG or DXF file first.", true);
    return;
  }

  const body = new FormData();
  body.append("file", file);
  body.append("dxf_version", document.getElementById("dxf_version").value);
  body.append("explode_blocks", document.getElementById("explode_blocks").checked);
  body.append("convert_splines", document.getElementById("convert_splines").checked);
  body.append(
    "include_display_only",
    document.getElementById("include_display_only").checked
  );
  body.append("flatten_z", document.getElementById("flatten_z").checked);

  const includeLayers = document.getElementById("include_layers").value.trim();
  const excludeLayers = document.getElementById("exclude_layers").value.trim();
  if (includeLayers) body.append("include_layers", includeLayers);
  if (excludeLayers) body.append("exclude_layers", excludeLayers);

  convertBtn.disabled = true;
  resultEl.hidden = true;
  setStatus("Converting linework for Trimble Access…");

  try {
    const response = await fetch("/api/convert", { method: "POST", body });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.detail || "Conversion failed.");
    }
    setStatus(
      payload.stakeable_count
        ? `Converted ${payload.stakeable_count} stakeable entit${
            payload.stakeable_count === 1 ? "y" : "ies"
          }.`
        : "Conversion finished — check warnings."
    );
    renderResult(payload);
  } catch (error) {
    setStatus(error.message || "Conversion failed.", true);
  } finally {
    convertBtn.disabled = false;
  }
});

// Hydrate field guide from API when available
fetch("/api/guide")
  .then((response) => (response.ok ? response.json() : null))
  .then((guide) => {
    if (!guide) return;
    const civil = document.getElementById("civil-steps");
    const trimble = document.getElementById("trimble-steps");
    if (civil && guide.civil3d_prep) {
      civil.innerHTML = guide.civil3d_prep.map((step) => `<li>${step}</li>`).join("");
    }
    if (trimble && guide.trimble_import) {
      trimble.innerHTML = guide.trimble_import.map((step) => `<li>${step}</li>`).join("");
    }
  })
  .catch(() => {});
