// Check the generated Godot Web bus code with lightweight Web Audio nodes.
// Run after build.py: node tools/web/check_audio_routing.cjs
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const runtime = fs.readFileSync(path.join(root, 'build/alonelab/dust-in-space/index.js'), 'utf8');
const start = runtime.indexOf('Bus:class Bus');
assert.ok(start >= 0, 'Generated runtime must expose its Bus class');
const body = runtime.indexOf('{', start);
let depth = 1;
let end = body + 1;
while (depth && end < runtime.length) {
  if (runtime[end] === '{') depth++;
  if (runtime[end] === '}') depth--;
  end++;
}
const source = runtime.slice(start + 4, end);
function routed(appendPosition) {
  const destination = {};
  const audio = { buses: [], ctx: { destination, createGain() {
    return { gain: { value: 1 }, outputs: [], connect(node) {
      this.outputs.push(node); return node;
    }, disconnect() { this.outputs = []; } };
  } } };
  audio.Bus = new Function('GodotAudio', `return (${source});`)(audio);
  audio.Bus.create(); // Master
  audio.Bus.addAt(appendPosition); // SFX
  audio.Bus.getBus(1).setSend(audio.Bus.getBus(0));
  // Follow the SFX output through the gain nodes to the device destination.
  const visited = new Set();
  function reaches(node) {
    if (node === destination) return true;
    if (visited.has(node)) return false;
    visited.add(node);
    return (node.outputs || []).some(reaches);
  }
  return reaches(audio.Bus.getBus(1).getInputNode());
}
const sfx = fs.readFileSync(path.join(root, 'game/fx/sfx.gd'), 'utf8');
assert.match(sfx, /AudioServer\.add_bus\(AudioServer\.bus_count\)/,
  'Append the SFX bus with an explicit position on Web');
assert.equal(routed(1), true, 'SFX must reach the output with explicit append');
console.log('PASS: explicit append routes SFX to the audio destination');
console.log(`Default append in this Godot runtime reaches output: ${routed(-1)}`);
