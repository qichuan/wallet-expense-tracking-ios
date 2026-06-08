import React from "react";
import {
  AbsoluteFill,
  OffthreadVideo,
  Sequence,
  staticFile,
  interpolate,
  useCurrentFrame,
} from "remotion";
import {
  CaptionStrip,
  FootageTap,
  ScrollHint,
  ActionType,
} from "./parts";
import { IntroCard, OutroCard } from "./Bookends";

// ---- Geometry ----
export const VIDEO_W = 720;
export const VIDEO_H = 1558; // source footage height
export const STRIP_H = 240;
export const COMP_W = VIDEO_W;
export const COMP_H = VIDEO_H + STRIP_H; // 1798

export const FOOTAGE_FRAMES = 1331; // 44.367s @ 30fps
export const INTRO_FRAMES = 42;
export const OUTRO_FRAMES = 70;
export const TOTAL_FRAMES = INTRO_FRAMES + FOOTAGE_FRAMES + OUTRO_FRAMES;

const TOTAL_STEPS = 9;

// Caption segments — times are in footage-seconds.
const CAPTIONS: {
  from: number;
  to: number;
  num: number;
  text: string;
  action: ActionType;
}[] = [
  { from: 0.0, to: 2.4, num: 1, text: "Open Shortcuts, then tap New Automation", action: "tap" },
  { from: 2.4, to: 6.2, num: 2, text: "Scroll down and choose Wallet", action: "scroll" },
  { from: 6.2, to: 9.2, num: 3, text: "Keep all your cards & categories selected", action: "check" },
  { from: 9.2, to: 11.2, num: 4, text: "Scroll down and turn on Run Immediately", action: "scroll" },
  { from: 11.2, to: 12.6, num: 5, text: "Tap Next", action: "tap" },
  { from: 12.6, to: 21.3, num: 6, text: "Search “CardPulse” and add Log Wallet Transaction", action: "tap" },
  { from: 21.3, to: 27.4, num: 7, text: "Tap the 1st field → Shortcut Input · Type Merchant", action: "tap" },
  { from: 27.4, to: 33.8, num: 8, text: "Next field → Shortcut Input · Type Amount", action: "tap" },
  { from: 33.8, to: 44.4, num: 9, text: "Last field → Shortcut Input · Type Card or Pass — done!", action: "done" },
];

// Tap pulses on the real footage — coords in 720x1558, time in footage-seconds.
const TAPS: { x: number; y: number; t: number }[] = [
  { x: 277, y: 363, t: 0.35 }, // Shortcuts icon
  { x: 359, y: 977, t: 1.6 }, // New Automation
  { x: 360, y: 1175, t: 5.6 }, // Wallet row
  { x: 250, y: 1290, t: 10.6 }, // Run Immediately
  { x: 633, y: 157, t: 11.4 }, // Next
  { x: 200, y: 413, t: 19.0 }, // Log Wallet Transaction result
  { x: 175, y: 498, t: 22.6 }, // Merchant field
  { x: 430, y: 500, t: 27.6 }, // Amount field
  { x: 235, y: 552, t: 34.0 }, // Card field
];

// Centered scroll hints — footage-seconds.
const SCROLL_HINTS: { from: number; to: number }[] = [
  { from: 2.8, to: 5.0 },
  { from: 9.3, to: 10.3 },
];

const FPS = 30;

const FootageWithOverlays: React.FC = () => {
  const frame = useCurrentFrame();
  const sec = frame / FPS;

  const active = CAPTIONS.find((c) => sec >= c.from && sec < c.to) ?? CAPTIONS[CAPTIONS.length - 1];

  const fadeIn = interpolate(frame, [0, 8], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const fadeOut = interpolate(frame, [FOOTAGE_FRAMES - 8, FOOTAGE_FRAMES], [1, 0], { extrapolateLeft: "clamp" });
  const progress = Math.min(1, frame / FOOTAGE_FRAMES);

  return (
    <AbsoluteFill style={{ background: "#000", opacity: fadeIn * fadeOut }}>
      {/* Real screen recording */}
      <OffthreadVideo
        src={staticFile("Setup-Automation.mp4")}
        muted
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          width: VIDEO_W,
          height: VIDEO_H,
        }}
      />

      {/* Overlays on the footage */}
      {SCROLL_HINTS.some((h) => sec >= h.from && sec < h.to) ? <ScrollHint /> : null}
      {TAPS.map((tp, i) => (
        <FootageTap key={i} x={tp.x} y={tp.y} at={Math.round(tp.t * FPS)} />
      ))}

      {/* Caption strip — keyed so it re-animates on each step change */}
      <CaptionStrip
        key={active.num}
        num={active.num}
        total={TOTAL_STEPS}
        text={active.text}
        action={active.action}
        top={VIDEO_H}
        height={STRIP_H}
      />

      {/* Progress bar along the very bottom */}
      <div
        style={{
          position: "absolute",
          left: 0,
          bottom: 0,
          height: 8,
          width: progress * COMP_W,
          background: "#FFD166",
        }}
      />
    </AbsoluteFill>
  );
};

export const AnnotatedSetup: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Sequence durationInFrames={INTRO_FRAMES}>
        <IntroCard />
      </Sequence>
      <Sequence from={INTRO_FRAMES} durationInFrames={FOOTAGE_FRAMES}>
        <FootageWithOverlays />
      </Sequence>
      <Sequence from={INTRO_FRAMES + FOOTAGE_FRAMES} durationInFrames={OUTRO_FRAMES}>
        <OutroCard />
      </Sequence>
    </AbsoluteFill>
  );
};
