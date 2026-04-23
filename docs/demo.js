(function() {
  'use strict';

  // ── Vault data ──────────────────────────────────────────
  var vault = [
    { kw: ['morning','routine','wake','gym','coffee'],
      raw: 'User wakes up at 6:30 AM, takes the 7:15 AM Caltrain from San Francisco to Palo Alto. Goes to Equinox for a 45-minute session, then picks up a Philz Coffee on the way to the office. Contact for gym buddy: Michael at michael.fit@gmail.com or 415-555-0192.' },
    { kw: ['work','job','office','colleague','meeting','team'],
      raw: 'Works at Google as a senior product manager. Direct reports include Sarah (sarah.chen@google.com, 650-555-0134) and James (james.okafor@google.com). Weekly 1:1 with VP David at 10:00 AM every Tuesday. Office is in Building 40, Mountain View. Badge ID tied to SSN 478-33-9182.' },
    { kw: ['finance','financial','money','bank','payment','card','salary'],
      raw: 'Primary checking at Chase, card ending 4111 1111 1111 1234. Monthly take-home after tax is $12,450. Rent is $3,200/month for the apartment in San Francisco. Auto-pay set up with card 3782 822463 10005. Financial advisor is Robert at robert.wealth@schwab.com, phone 212-555-0198.' },
    { kw: ['health','doctor','medical','fitness','prescription','patient'],
      raw: 'Primary care physician is Dr. Emily Park at Kaiser Permanente, San Francisco. Patient born in 1991, age 35, blood type O+. Current prescription for atorvastatin refilled monthly. Emergency contact: Jennifer at 510-555-0147. Patient portal login tied to emily.patient@kaiser.org. Last visit IP logged from 192.168.1.42.' },
    { kw: ['travel','flight','hotel','trip','vacation','airport'],
      raw: 'Upcoming trip to Nashville on March 28. Delta flight DL1847 departing San Francisco at 8:45 AM, confirmation JKXR29. Hotel: The Hermitage, booked under Jane Smith, jane.s@outlook.com, phone +1-615-555-0123. Passport number redacted but SSN on file: 291-55-8734. Travel insurance through Amazon at $89.99.' },
    { kw: ['family','home','personal','kids','spouse','partner'],
      raw: 'Lives with partner Lisa in the Noe Valley neighborhood of San Francisco. Lisa works at Apple as a design lead. Two kids enrolled at Pleasanton Elementary. Home network IP: 10.0.0.1. Family plan phone: 415-555-0201. Joint savings goal: $50,000 by end of year. Lisa turns aged 33 on April 12.' }
  ];

  // ── Redaction engine ────────────────────────────────────
  var piiPatterns = [
    { rx: /\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b/g, tag: 'SSN REDACTED' },
    { rx: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, tag: 'EMAIL REDACTED' },
    { rx: /(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}(?!\d)/g, tag: 'PHONE REDACTED' },
    { rx: /\b(?:\d{4}[-\s]?){3}\d{1,4}\b|\b\d{4}[-\s]?\d{6}[-\s]?\d{5}\b/g, tag: 'CARD REDACTED' },
    { rx: /\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b/g, tag: 'IP REDACTED' }
  ];

  var names = ['John','Jane','Michael','Sarah','David','Emily','Robert','Maria','James','Jennifer','William','Jessica','Richard','Lisa','Daniel','Amanda'];
  var cities = ['New York','Los Angeles','Chicago','San Francisco','Seattle','Austin','Boston','Denver','Miami','Portland','Nashville','Atlanta','Dallas','Phoenix','Philadelphia','Pleasanton','Palo Alto','Mountain View'];
  var orgs = ['Google','Apple','Microsoft','Amazon','Meta','Netflix','Spotify','Uber','Nike','Equinox','Kaiser Permanente','Chase'];
  cities.sort(function(a,b){return b.length-a.length;});
  orgs.sort(function(a,b){return b.length-a.length;});

  var timeRx = /\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)\b/g;
  var amountRx = /[$\u20ac\u00a3]\s?\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?/g;
  var ageRx = /\bage(?:d)?\s+\d{1,3}\b/g;

  function esc(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

  function redact(text) {
    var count = 0;
    piiPatterns.forEach(function(p) {
      p.rx.lastIndex = 0;
      text = text.replace(p.rx, function() { count++; return '[' + p.tag + ']'; });
    });
    names.forEach(function(n) {
      text = text.replace(new RegExp('\\b' + n + '\\b', 'g'), function() { count++; return '[PERSON]'; });
    });
    cities.forEach(function(c) {
      text = text.replace(new RegExp('\\b' + esc(c) + '\\b', 'g'), function() { count++; return '[LOCATION]'; });
    });
    orgs.forEach(function(o) {
      text = text.replace(new RegExp('\\b' + esc(o) + '\\b', 'g'), function() { count++; return '[ORGANIZATION]'; });
    });
    text = text.replace(timeRx, function() { count++; return '[TIME GENERALIZED]'; });
    text = text.replace(amountRx, function() { count++; return '[AMOUNT GENERALIZED]'; });
    text = text.replace(ageRx, function() { count++; return '[AGE REDACTED]'; });
    return { text: text, count: count };
  }

  function queryVault(q) {
    var tokens = q.toLowerCase().split(/\s+/).filter(function(t){return t.length>2;});
    var hits = [];
    vault.forEach(function(e) {
      var match = tokens.some(function(t) {
        return e.kw.some(function(k) { return k.indexOf(t)>=0 || t.indexOf(k)>=0; });
      });
      if (match) hits.push(e.raw);
    });
    var raw = hits.length > 0 ? hits.join(' ') : 'No matching data found.';
    var r = redact(raw);
    return { data: r.text, redactions: r.count, hits: hits.length };
  }

  function fakeUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      var r = Math.random()*16|0; return (c==='x'?r:(r&0x3|0x8)).toString(16);
    });
  }

  // ── DOM helpers ─────────────────────────────────────────
  var termOut = document.getElementById('term-output');
  var termControls = document.getElementById('term-controls');
  var termFree = document.getElementById('term-free');
  var dashAgents = document.getElementById('dash-agents');
  var dashAudit = document.getElementById('dash-audit');
  var token = '';
  var step = 0;
  var busy = false;

  function mkEl(tag, cls, text) {
    var el = document.createElement(tag);
    if (cls) el.className = cls;
    if (text) el.textContent = text;
    return el;
  }

  function addTermCmd(text) {
    var d = mkEl('div', 'term-cmd', text);
    termOut.appendChild(d);
    termOut.scrollTop = termOut.scrollHeight;
  }

  function addTermResp(jsonObj) {
    var raw = JSON.stringify(jsonObj, null, 2);
    var d = mkEl('div', 'term-resp');
    // Build text nodes and redaction spans safely
    var parts = raw.split(/(\[[A-Z\s]+\])/g);
    parts.forEach(function(part) {
      if (/^\[[A-Z\s]+\]$/.test(part)) {
        var s = document.createElement('span');
        s.className = 'r';
        s.textContent = part;
        d.appendChild(s);
      } else {
        d.appendChild(document.createTextNode(part));
      }
    });
    termOut.appendChild(d);
    termOut.scrollTop = termOut.scrollHeight;
  }

  function addTermInfo(text) {
    termOut.appendChild(mkEl('div', 'term-info', text));
    termOut.scrollTop = termOut.scrollHeight;
  }

  function addSpacer() {
    termOut.appendChild(mkEl('div', 'term-spacer'));
  }

  function addAudit(action, agentId, extra) {
    var first = dashAudit.querySelector('.dash-empty');
    if (first) first.remove();
    var d = mkEl('div', 'dash-audit-entry');
    var time = new Date().toLocaleTimeString('en-US',{hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false});
    var ts = mkEl('span', null, time + ' ');
    ts.style.color = 'var(--text-muted)';
    d.appendChild(ts);
    var act = mkEl('span', 'audit-action', action + ' ');
    d.appendChild(act);
    d.appendChild(document.createTextNode(agentId + ' '));
    if (extra) {
      var ex = mkEl('span', 'audit-count', extra);
      d.appendChild(ex);
    }
    dashAudit.insertBefore(d, dashAudit.firstChild);
  }

  function addAgent(name) {
    var first = dashAgents.querySelector('.dash-empty');
    if (first) first.remove();
    var d = mkEl('div', 'dash-agent-row');
    d.appendChild(document.createTextNode(name + ' '));
    var badge = mkEl('span', 'dash-badge dash-badge-active', 'active');
    d.appendChild(badge);
    dashAgents.appendChild(d);
  }

  function typeText(text, cb) {
    var i = 0;
    var el = mkEl('div', 'term-cmd');
    termOut.appendChild(el);
    var iv = setInterval(function() {
      el.textContent += text[i];
      i++;
      termOut.scrollTop = termOut.scrollHeight;
      if (i >= text.length) { clearInterval(iv); if(cb) setTimeout(cb, 400); }
    }, 18);
  }

  // ── Guided steps ────────────────────────────────────────
  var guidedSteps = [
    function(done) {
      addTermInfo('Step 1: Authenticate an agent');
      addSpacer();
      typeText('curl -X POST localhost:8432/api/v1/auth/request -H "Content-Type: application/json" -d \'{"app_id":"demo-agent","app_name":"Demo Agent","scopes":["context.read"],"intent":"interactive demo"}\'', function() {
        token = fakeUUID();
        addSpacer();
        addTermResp({status:'success',access_token:token,expires_in:900,granted_scopes:['context.read']});
        addAgent('demo-agent');
        addAudit('granted', 'demo-agent', 'ttl=900s');
        addSpacer();
        done();
      });
    },
    function(done) {
      addTermInfo('Step 2: Query "morning routine"');
      addSpacer();
      typeText('curl -X POST localhost:8432/api/v1/context/query -H "Authorization: Bearer ' + token.substring(0,8) + '..." -d \'{"query":"morning routine"}\'', function() {
        var r = queryVault('morning routine');
        addSpacer();
        addTermResp({status:'success',data:r.data,privacy_level:'strict',redactions_applied:r.redactions});
        addAudit('redacted', 'demo-agent', r.redactions + ' redactions');
        addSpacer();
        done();
      });
    },
    function(done) {
      addTermInfo('Step 3: Query "work colleagues"');
      addSpacer();
      typeText('curl -X POST localhost:8432/api/v1/context/query -H "Authorization: Bearer ' + token.substring(0,8) + '..." -d \'{"query":"work colleagues"}\'', function() {
        var r = queryVault('work colleagues');
        addSpacer();
        addTermResp({status:'success',data:r.data,privacy_level:'strict',redactions_applied:r.redactions});
        addAudit('redacted', 'demo-agent', r.redactions + ' redactions');
        addSpacer();
        done();
      });
    }
  ];

  window.demoNextStep = function() {
    if (busy) return;
    var btn = document.getElementById('term-next');
    if (step < guidedSteps.length) {
      busy = true;
      btn.disabled = true;
      btn.textContent = 'Running...';
      guidedSteps[step](function() {
        step++;
        busy = false;
        btn.disabled = false;
        if (step < guidedSteps.length) {
          btn.textContent = 'Next step (' + (step+1) + '/' + guidedSteps.length + ')';
        } else {
          termControls.style.display = 'none';
          termFree.style.display = '';
          addTermInfo('Try it yourself \u2014 click a preset or type a query below.');
          addSpacer();
        }
      });
    }
  };

  // ── Free input ──────────────────────────────────────────
  window.demoQuery = function(q) {
    if (!q || busy) return;
    var inp = document.getElementById('term-input');
    if (inp) inp.value = '';
    busy = true;
    addTermCmd('curl -X POST localhost:8432/api/v1/context/query -d \'{"query":"' + q + '"}\'');
    addSpacer();
    setTimeout(function() {
      var r = queryVault(q);
      addTermResp({status:'success',data:r.data,privacy_level:'strict',redactions_applied:r.redactions});
      if (r.hits === 0) {
        addAudit('query', 'demo-agent', 'no vault match');
      } else {
        addAudit('redacted', 'demo-agent', r.redactions + ' redactions');
      }
      addSpacer();
      busy = false;
      termOut.scrollTop = termOut.scrollHeight;
    }, 300);
  };
})();
