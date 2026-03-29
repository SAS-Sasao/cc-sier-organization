#!/usr/bin/env node
/**
 * draw.io XML reviewer: detects edges that penetrate intermediate nodes.
 *
 * Usage: node review-drawio.js <path-to-.drawio-file>
 *
 * Exit codes:
 *   0  no issues found
 *   1  issues detected (details printed to stdout)
 *   2  usage / file error
 */
"use strict";

const fs = require("fs");
const path = require("path");

const file = process.argv[2];
if (!file) {
  console.error("Usage: node review-drawio.js <file.drawio>");
  process.exit(2);
}
if (!fs.existsSync(file)) {
  console.error("File not found:", file);
  process.exit(2);
}

const xml = fs.readFileSync(file, "utf8");

// --- Parse mxCells ---------------------------------------------------------
const cellRe = /<mxCell\s+([\s\S]*?)(?:\/>|>([\s\S]*?)<\/mxCell>)/g;
const nodes = new Map();
const edges = [];

let match;
while ((match = cellRe.exec(xml)) !== null) {
  const attrs = match[1];
  const inner = match[2] || "";
  const id = attr(attrs, "id");
  const style = attr(attrs, "style") || "";
  const parentId = attr(attrs, "parent");
  const value = attr(attrs, "value") || "";
  const isEdge = /edge="1"/.test(attrs);
  const source = attr(attrs, "source");
  const target = attr(attrs, "target");

  const geo = inner.match(/<mxGeometry\s+([\s\S]*?)\/?>/);
  let x = 0, y = 0, w = 0, h = 0;
  if (geo) {
    x = num(geo[1], "x");
    y = num(geo[1], "y");
    w = num(geo[1], "width");
    h = num(geo[1], "height");
  }

  if (isEdge && source && target) {
    // Parse waypoints from <Array as="points"><mxPoint x="..." y="..."/></Array>
    const waypoints = [];
    const wpMatches = inner.matchAll(/<mxPoint\s+x="([^"]*)"\s+y="([^"]*)"/g);
    for (const wp of wpMatches) {
      waypoints.push({ x: parseFloat(wp[1]), y: parseFloat(wp[2]) });
    }
    edges.push({ id, source, target, style, waypoints });
  } else if (w > 0 && h > 0) {
    nodes.set(id, { id, x, y, w, h, parent: parentId, value });
  }
}

function attr(s, name) {
  const m = s.match(new RegExp(name + '="([^"]*)"'));
  return m ? m[1] : undefined;
}
function num(s, name) {
  const m = s.match(new RegExp(name + '="([^"]*)"'));
  return m ? parseFloat(m[1]) : 0;
}

// --- Resolve absolute coordinates ------------------------------------------
function absCoords(node) {
  let ax = node.x, ay = node.y;
  let cur = node;
  while (cur.parent && nodes.has(cur.parent)) {
    const p = nodes.get(cur.parent);
    ax += p.x;
    ay += p.y;
    // swimlane startSize offset
    if (p.value && /swimlane/.test(getStyle(p))) {
      ay += 30; // default startSize
    }
    cur = p;
  }
  return { x: ax, y: ay, w: node.w, h: node.h };
}

function getStyle(node) {
  // re-read style from xml for the node
  const re = new RegExp('id="' + node.id + '"[^>]*style="([^"]*)"');
  const m = xml.match(re);
  return m ? m[1] : "";
}

// --- Build absolute bounding boxes -----------------------------------------
const boxes = new Map();
for (const [id, node] of nodes) {
  boxes.set(id, absCoords(node));
}

// --- Check edge penetration ------------------------------------------------
function boxContainsPoint(box, px, py) {
  return px > box.x && px < box.x + box.w && py > box.y && py < box.y + box.h;
}

function segmentIntersectsBox(x1, y1, x2, y2, box) {
  // Check if line segment (x1,y1)-(x2,y2) passes through box interior
  // Sample points along the segment
  const steps = 20;
  for (let i = 1; i < steps; i++) {
    const t = i / steps;
    const px = x1 + (x2 - x1) * t;
    const py = y1 + (y2 - y1) * t;
    if (boxContainsPoint(box, px, py)) return true;
  }
  return false;
}

function centerOf(box) {
  return { cx: box.x + box.w / 2, cy: box.y + box.h / 2 };
}

const issues = [];

for (const edge of edges) {
  const srcBox = boxes.get(edge.source);
  const tgtBox = boxes.get(edge.target);
  if (!srcBox || !tgtBox) continue;

  const src = centerOf(srcBox);
  const tgt = centerOf(tgtBox);

  // Check all other nodes (excluding containers of src/tgt)
  const srcNode = nodes.get(edge.source);
  const tgtNode = nodes.get(edge.target);
  const excludeIds = new Set([
    edge.source, edge.target,
    srcNode?.parent, tgtNode?.parent,
    "0", "1"
  ]);

  // Also exclude parent containers of parents (grandparents)
  if (srcNode?.parent && nodes.has(srcNode.parent)) {
    excludeIds.add(nodes.get(srcNode.parent).parent);
  }
  if (tgtNode?.parent && nodes.has(tgtNode.parent)) {
    excludeIds.add(nodes.get(tgtNode.parent).parent);
  }

  // Build path segments: source -> wp1 -> wp2 -> ... -> target
  const points = [{ x: src.cx, y: src.cy }];
  if (edge.waypoints && edge.waypoints.length > 0) {
    for (const wp of edge.waypoints) points.push({ x: wp.x, y: wp.y });
  }
  points.push({ x: tgt.cx, y: tgt.cy });

  for (const [nodeId, box] of boxes) {
    if (excludeIds.has(nodeId)) continue;

    // Skip swimlane containers (they are large regions, not visual objects)
    const style = getStyle(nodes.get(nodeId));
    if (/swimlane/.test(style)) continue;

    // Check each segment of the path
    let penetrates = false;
    for (let s = 0; s < points.length - 1; s++) {
      if (segmentIntersectsBox(points[s].x, points[s].y, points[s+1].x, points[s+1].y, box)) {
        penetrates = true;
        break;
      }
    }

    if (penetrates) {
      const nodeVal = (nodes.get(nodeId)?.value || nodeId).replace(/&#xa;/g, " ").substring(0, 30);
      const srcVal = (nodes.get(edge.source)?.value || edge.source).replace(/&#xa;/g, " ").substring(0, 30);
      const tgtVal = (nodes.get(edge.target)?.value || edge.target).replace(/&#xa;/g, " ").substring(0, 30);
      issues.push({
        edge: edge.id,
        from: srcVal,
        to: tgtVal,
        penetrates: nodeVal,
      });
    }
  }
}

// --- Output ----------------------------------------------------------------
if (issues.length === 0) {
  console.log("OK: No edge penetration issues detected.");
  process.exit(0);
} else {
  console.log(`WARN: ${issues.length} edge penetration issue(s) detected:\n`);
  for (const issue of issues) {
    console.log(`  Edge [${issue.edge}]: "${issue.from}" -> "${issue.to}"`);
    console.log(`    penetrates node: "${issue.penetrates}"\n`);
  }
  console.log("Suggestion: Increase node spacing or add explicit waypoints to avoid penetration.");
  process.exit(1);
}
