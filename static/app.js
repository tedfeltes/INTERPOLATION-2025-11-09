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

function commonFormData(file) {
  const body = new FormData();
  body.append("file", file);
  body.append("dxf_version", document.getElementById("dxf_version").value);
  body.append("explode_blocks", document.getElementById("explode_blocks").checked);
  body.append("convert_splines", document.getElementById("convert_splines").checked);
  body.append("explode_proxies", document.getElementById("explode_proxies").checked);
  body.append("include_display_only", "false");
  body.append("flatten_z", document.getElementById("flatten_z").checked);
  const includeLayers = document.getElementById("include_layers").value.trim();
  const excludeLayers = document.getElementById("exclude_layers").value.trim();
  if (includeLayers) body.append("include_layers", includeLayers);
  if (excludeLayers) body.append("exclude_layers", excludeLayers);
  return body;
}

function renderResult(payload, blobUrl, filename) {
  resultEl.hidden = false;
  downloadLink.href = blobUrl || payload.download_url;
  downloadLink.download = filename || payload.output_name || "trimble_access.dxf";
  // iOS Safari: open in new tab sometimes helps "Share / Save to Files"
  downloadLink.target = "_blank";
  downloadLink.rel = "noopener";

  const items = [
    ["Stakeable", payload.stakeable_count],
    ["Proxies recovered", payload.proxy_carriers_exploded ?? 0],
    ["Engine", payload.engine],
    ["DXF", payload.dxf_version],
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
    .slice(0, 24)
    .map(
      (layer) =>
        `<span class="layer-pill">${layer.name} · ${layer.stakeable_count}</span>`
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
    setStatus("Choose a DWG from OneDrive / Files first.", true);
    return;
  }

  convertBtn.disabled = true;
  resultEl.hidden = true;
  setStatus("Uploading to cloud converter…");

  try {
    // JSON metadata convert (shows stats) then provide download URL.
    // Also request binary convert-file as a blob for reliable iOS Save-to-Files.
    const metaResponse = await fetch("/api/convert", {
      method: "POST",
      body: commonFormData(file),
    });
    const payload = await metaResponse.json().catch(() => ({}));
    if (!metaResponse.ok) {
      throw new Error(payload.detail || "Conversion failed.");
    }

    setStatus("Preparing DXF download…");
    const fileResponse = await fetch("/api/convert-file", {
      method: "POST",
      body: commonFormData(file),
    });
    if (!fileResponse.ok) {
      // Fall back to JSON job download URL
      const proxyNote = payload.proxy_carriers_exploded
        ? ` Recovered ${payload.proxy_carriers_exploded} Civil 3D proxy object(s).`
        : "";
      setStatus(
        payload.stakeable_count
          ? `Ready — ${payload.stakeable_count} stakeable entities.${proxyNote}`
          : "Conversion finished — check warnings."
      );
      renderResult(payload);
      return;
    }

    const blob = await fileResponse.blob();
    const filename =
      payload.output_name ||
      (file.name.replace(/\.(dwg|dxf)$/i, "") + "_trimble_access.dxf");
    const blobUrl = URL.createObjectURL(blob);
    const proxyNote = payload.proxy_carriers_exploded
      ? ` Recovered ${payload.proxy_carriers_exploded} Civil 3D proxy object(s).`
      : "";
    setStatus(
      payload.stakeable_count
        ? `Ready — ${payload.stakeable_count} stakeable entities.${proxyNote}`
        : "Conversion finished — check warnings."
    );
    renderResult(payload, blobUrl, filename);
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
    const iphone = document.getElementById("iphone-steps");
    const tsc5 = document.getElementById("tsc5-steps");
    if (iphone && guide.iphone_steps) {
      iphone.innerHTML = guide.iphone_steps.map((step) => `<li>${step}</li>`).join("");
    }
    if (tsc5 && guide.tsc5_steps) {
      tsc5.innerHTML = guide.tsc5_steps.map((step) => `<li>${step}</li>`).join("");
    }
  })
  .catch(() => {});
