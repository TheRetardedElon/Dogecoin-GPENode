/** Dogecoin GPENode — public operator docs sidebar */
(function () {
  var path = (window.location.pathname || "").replace(/\\/g, "/");
  var inPages = /\/pages\//.test(path);
  if (!inPages) {
    var scripts = document.getElementsByTagName("script");
    for (var i = 0; i < scripts.length; i++) {
      var src = scripts[i].getAttribute("src") || "";
      if (src.indexOf("../assets/nav.js") !== -1) inPages = true;
    }
  }
  var p = inPages ? "" : "pages/";
  var root = inPages ? "../" : "";
  function link(href, label) {
    return '<a href="' + href + '">' + label + "</a>";
  }
  var html = "";
  html += '<div class="nav-section">GPENode</div>';
  html += link(root + "index.html", "Dashboard");
  html += link(p + "gpenode.html", "Overview");
  html += link(p + "operator-roadmap.html", "Roadmap");
  html += link(p + "multi-operator-mesh.html", "Mesh");
  html += link(p + "source-of-truth.html", "Source of truth");

  html += '<div class="nav-section">Fast Sync / CDN</div>';
  html += link(p + "fast-sync.html", "Fast Sync (clients)");
  html += link(p + "fast-sync-threat-model.html", "Threat model");
  html += link(p + "storage-stack.html", "Storage stack");
  html += link(p + "diagrams.html", "Diagrams");

  html += '<div class="nav-section">Daemon reference</div>';
  html += link(p + "assumeutxo.html", "AssumeUTXO");
  html += link(p + "ibd-and-p2p.html", "IBD &amp; P2P");
  html += link(p + "architecture.html", "Architecture");
  html += link(p + "glossary.html", "Glossary");

  html += '<div class="nav-section">Product</div>';
  html += link(p + "payment-layer.html", "Payment layer");
  html += link(p + "pure-doge-strategy.html", "Pure DOGE");

  var nav = document.querySelector(".sidebar nav");
  if (nav) nav.innerHTML = html;

  var file = path.split("/").pop() || "index.html";
  if (!file || file.indexOf(".") === -1) file = "index.html";
  document.querySelectorAll(".sidebar nav a[href]").forEach(function (a) {
    var target = (a.getAttribute("href") || "").split("/").pop();
    if (target === file) a.classList.add("active");
  });
})();
