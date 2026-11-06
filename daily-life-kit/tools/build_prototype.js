// Builds a standalone, browser-runnable prototype (prototype/index.html) from Main.dc.html.
// Usage: node build_prototype.js <Main.dc.html> <morphdom-umd.min.js> <out.html>
const fs = require('fs');
const [,, mainPath, morphPath, outPath] = process.argv;
const src = fs.readFileSync(mainPath, 'utf8');
const helmet = src.match(/<helmet>([\s\S]*?)<\/helmet>/)[1];
const tpl = src.match(/<x-dc>([\s\S]*?)<\/x-dc>/)[1].replace(/<helmet>[\s\S]*?<\/helmet>/, '');
const script = src.match(/<script type="text\/x-dc" data-dc-script[^>]*>([\s\S]*?)<\/script>/)[1];
const morph = fs.readFileSync(morphPath, 'utf8');
const j = s => JSON.stringify(s).replace(/<\//g, '<\\/');

const runtime = `
(function () {
  var TPL = ${j(tpl)};
  var SCRIPT = ${j(script)};
  var root = document.getElementById('app');
  var pending = false, lastSig = null, H = [], comp;
  function schedule() { if (pending) return; pending = true; Promise.resolve().then(function () { pending = false; draw(); }); }
  class DCLogic {
    constructor(props) { this.props = props || {}; this.state = {}; }
    setState(u, cb) { var v = typeof u === 'function' ? u(this.state, this.props) : u; this.state = Object.assign({}, this.state, v); schedule(); if (cb) Promise.resolve().then(cb); }
    forceUpdate() { schedule(); }
  }
  var Component = new Function('DCLogic', SCRIPT + '\\nreturn Component;')(DCLogic);
  function parse(t) {
    var re = /<(\\/?)(sc-if|sc-for)\\b([^>]*)>/g, rootN = { kids: [] }, stack = [rootN], last = 0, m;
    while ((m = re.exec(t))) { var cur = stack[stack.length - 1]; cur.kids.push({ text: t.slice(last, m.index) });
      if (m[1]) stack.pop(); else { var n = { tag: m[2], attrs: m[3], kids: [] }; cur.kids.push(n); stack.push(n); } last = re.lastIndex; }
    stack[0].kids.push({ text: t.slice(last) }); return rootN;
  }
  var tree = parse(TPL);
  function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;'); }
  function css(o) { return Object.keys(o).map(function (k) { return (k.indexOf('--') === 0 ? k : k.replace(/[A-Z]/g, function (c) { return '-' + c.toLowerCase(); })) + ':' + o[k]; }).join(';'); }
  function get(sc, p) { p = p.trim(); if (p === 'true') return true; if (p === 'false') return false; if (/^-?\\d+(\\.\\d+)?$/.test(p)) return Number(p); var v = sc, ks = p.split('.'); for (var i = 0; i < ks.length; i++) { if (v == null) return undefined; v = v[ks[i]]; } return v; }
  function fill(text, sc) {
    text = text.replace(/([\\w-]+)="\\{\\{\\s*([^}]+?)\\s*\\}\\}"/g, function (m, n, p) {
      var v = get(sc, p);
      if (/^on[A-Z]/.test(n)) { if (typeof v !== 'function') return ''; return 'data-' + n.toLowerCase() + '="' + (H.push(v) - 1) + '"'; }
      if (typeof v === 'function' || v == null) return '';
      if (n === 'style' && typeof v === 'object') return 'style="' + esc(css(v)) + '"';
      if (typeof v === 'boolean') return n === 'disabled' ? (v ? 'disabled' : '') : n + '="' + v + '"';
      return n + '="' + esc(v) + '"';
    });
    return text.replace(/\\{\\{\\s*([^}]+?)\\s*\\}\\}/g, function (m, p) { var v = get(sc, p); return v == null ? '' : esc(v); });
  }
  function render(node, sc) {
    var out = '';
    node.kids.forEach(function (k) {
      if (k.text != null) out += fill(k.text, sc);
      else if (k.tag === 'sc-if') { if (get(sc, k.attrs.match(/value="\\{\\{\\s*([^}]+?)\\s*\\}\\}"/)[1])) out += render(k, sc); }
      else { var lp = k.attrs.match(/list="\\{\\{\\s*([^}]+?)\\s*\\}\\}"/)[1], as = k.attrs.match(/as="(\\w+)"/)[1];
        (get(sc, lp) || []).forEach(function (it, i) { var s2 = Object.create(sc); s2[as] = it; s2.$index = i; out += render(k, s2); }); }
    });
    return out;
  }
  function post(html) {
    html = html.replace(/<textarea([^>]*?)\\svalue="([^"]*)"([^>]*)><\\/textarea>/g, '<textarea$1$3>$2</textarea>');
    return html.replace(/<select([^>]*?)\\svalue="([^"]*)"([^>]*)>([\\s\\S]*?)<\\/select>/g, function (m, a, v, b, opts) {
      return '<select' + a + b + '>' + opts.replace(new RegExp('<option value="' + v.replace(/[.*+?^$()|[\\]\\\\]/g, '\\\\$&') + '"'), '<option selected value="' + v + '"') + '</select>';
    });
  }
  function draw() {
    H = [];
    var V = comp.renderVals(), html = post(render(tree, V)), tmp = document.createElement('div');
    tmp.innerHTML = html; var next = tmp.querySelector('.dl');
    var sig = comp.state.stack.map(function (x) { return x.s + JSON.stringify(x.p); }).join('/');
    if (sig !== lastSig || !root.firstElementChild) { root.innerHTML = ''; root.appendChild(next); }
    else morphdom(root.firstElementChild, next);
    lastSig = sig;
  }
  function fire(attr, e) {
    var el = e.target.closest('[' + attr + ']'); if (!el || !root.contains(el) || el.disabled) return;
    var f = H[+el.getAttribute(attr)]; if (f) f({ target: el, currentTarget: el, stopPropagation: function () {}, preventDefault: function () {} });
  }
  root.addEventListener('click', function (e) { fire('data-onclick', e); });
  root.addEventListener('input', function (e) { fire('data-onchange', e); });
  var q = new URLSearchParams(location.search);
  comp = new Component({ theme: q.get('theme') || 'light', lang: q.get('lang') || 'bn', start: q.get('start') || 'welcome' });
  draw();
  if (comp.componentDidMount) comp.componentDidMount();
  window.__dailyLife = comp;
})();`;

const html = `<!doctype html>
<html lang="bn">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Daily Life — interactive prototype</title>
${helmet.trim()}
<style>
html,body{margin:0;min-height:100%;background:#E5E7EB}
.stage{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:24px;box-sizing:border-box}
#app>.dl{border-radius:28px;box-shadow:0 24px 64px rgba(15,23,42,.25)}
@media (max-width:440px){.stage{padding:0}#app>.dl{border-radius:0;box-shadow:none}}
</style>
</head>
<body>
<div class="stage"><div id="app"></div></div>
<!-- Query params: ?start=home|finance|calendar|work|more|settings|...&theme=light|dark|system&lang=bn|en -->
<script>${morph}</script>
<script>${runtime}</script>
</body>
</html>
`;
fs.writeFileSync(outPath, html);
console.log('wrote', outPath, html.length, 'bytes');
