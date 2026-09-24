import React from "react";
import {
  AbsoluteFill,
  Freeze,
  OffthreadVideo,
  Sequence,
  staticFile,
  interpolate,
  useCurrentFrame,
} from "remotion";
import { CaptionStrip, FootageTap, ActionType } from "./parts";
import { IntroCard, OutroCard } from "./Bookends";

// ---- Geometry ----
// Source is an iOS 27 screen recording (public/Setup-Automation.mp4). iOS
// records variable-frame-rate HEVC, which <Freeze> can't seek accurately, so
// the composition reads a constant-30fps 720x1558 copy made by
// `npm run footage`. All tap coordinates below are in 720x1558 space.
export const VIDEO_W = 720;
export const VIDEO_H = 1558;
export const STRIP_H = 240;
export const COMP_W = VIDEO_W;
export const COMP_H = VIDEO_H + STRIP_H; // 1798

export const INTRO_FRAMES = 42;
export const OUTRO_FRAMES = 80;

const FPS = 30;
const SRC = "Setup-Automation.30fps.mp4";
const TOTAL_STEPS = 8;

type Tap = { x: number; y: number; t: number }; // t = source seconds

type Step = {
  num: number;
  text: string;
  action: ActionType;
  fromSec: number; // source segment played during this step
  toSec: number;
  pause: number; // read-hold frames before the segment plays
  taps: Tap[];
};

// Each step: hold on its first frame (so the instruction can be read), then
// play that slice of the real recording at 1x with the tap highlight.
const STEPS: Step[] = [
  {
    num: 1,
    text: "Open Shortcuts and tap New Shortcut",
    action: "tap",
    fromSec: 0.0,
    toSec: 4.8,
    pause: 60,
    taps: [
      { x: 277, y: 720, t: 0.8 },
      { x: 190, y: 497, t: 4.2 },
    ],
  },
  {
    num: 2,
    text: "Tap Search, then the Automation category",
    action: "tap",
    fromSec: 4.8,
    toSec: 7.4,
    pause: 60,
    taps: [
      { x: 175, y: 813, t: 5.3 },
      { x: 180, y: 263, t: 7.2 },
    ],
  },
  {
    num: 3,
    text: "Scroll down to Apps and choose Wallet",
    action: "scroll",
    fromSec: 7.4,
    toSec: 13.2,
    pause: 55,
    taps: [{ x: 250, y: 860, t: 12.7 }],
  },
  {
    num: 4,
    text: "Search “Log” and add Log Wallet Transaction",
    action: "type",
    fromSec: 13.2,
    toSec: 21.3,
    pause: 75,
    taps: [
      { x: 200, y: 1364, t: 15.2 },
      { x: 300, y: 500, t: 20.7 },
    ],
  },
  {
    num: 5,
    text: "Tap Merchant Name → Select Variable → Transaction",
    action: "tap",
    fromSec: 21.3,
    toSec: 28.5,
    pause: 80,
    taps: [
      { x: 200, y: 522, t: 23.2 },
      { x: 170, y: 880, t: 24.8 },
      { x: 380, y: 497, t: 27.2 },
    ],
  },
  {
    num: 6,
    text: "Tap Transaction again and choose Merchant",
    action: "tap",
    fromSec: 28.5,
    toSec: 33.0,
    pause: 70,
    taps: [
      { x: 180, y: 522, t: 28.7 },
      { x: 250, y: 1336, t: 30.7 },
    ],
  },
  {
    num: 7,
    text: "Same for Amount, then choose Amount",
    action: "tap",
    fromSec: 33.0,
    toSec: 41.6,
    pause: 70,
    taps: [
      { x: 425, y: 526, t: 33.2 },
      { x: 170, y: 880, t: 34.7 },
      { x: 380, y: 497, t: 36.2 },
      { x: 490, y: 522, t: 38.2 },
      { x: 250, y: 1426, t: 39.3 },
    ],
  },
  {
    num: 8,
    text: "Same for Card Name, choose Card or Pass — done!",
    action: "done",
    fromSec: 41.6,
    toSec: 55.0,
    pause: 80,
    taps: [
      { x: 200, y: 580, t: 41.8 },
      { x: 165, y: 1089, t: 43.2 },
      { x: 380, y: 497, t: 44.8 },
      { x: 205, y: 583, t: 46.8 },
      { x: 250, y: 1242, t: 49.7 },
      { x: 68, y: 126, t: 53.3 },
    ],
  },
];

const stepDuration = (s: Step) =>
  s.pause + Math.round((s.toSec - s.fromSec) * FPS);

export const FOOTAGE_FRAMES = STEPS.reduce((a, s) => a + stepDuration(s), 0);
export const TOTAL_FRAMES = INTRO_FRAMES + FOOTAGE_FRAMES + OUTRO_FRAMES;

const videoStyle: React.CSSProperties = {
  position: "absolute",
  top: 0,
  left: 0,
  width: VIDEO_W,
  height: VIDEO_H,
};

const StepBlock: React.FC<{ step: Step }> = ({ step }) => {
  const frame = useCurrentFrame();
  const fromFrame = Math.round(step.fromSec * FPS);
  const playing = frame >= step.pause;

  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {/* Footage: freeze on the first frame while the user reads, then play. */}
      {!playing ? (
        <Freeze frame={0}>
          <OffthreadVideo
            src={staticFile(SRC)}
            muted
            startFrom={fromFrame}
            style={videoStyle}
          />
        </Freeze>
      ) : null}
      <Sequence from={step.pause}>
        <OffthreadVideo
          src={staticFile(SRC)}
          muted
          startFrom={fromFrame}
          style={videoStyle}
        />
      </Sequence>

      {/* Overlays */}
      {step.taps.map((tp, i) => (
        <FootageTap
          key={i}
          x={tp.x}
          y={tp.y}
          at={step.pause + Math.round((tp.t - step.fromSec) * FPS)}
        />
      ))}

      <CaptionStrip
        key={step.num}
        num={step.num}
        total={TOTAL_STEPS}
        text={step.text}
        action={step.action}
        top={VIDEO_H}
        height={STRIP_H}
      />
    </AbsoluteFill>
  );
};

const FootageSection: React.FC = () => {
  const frame = useCurrentFrame();
  const fadeIn = interpolate(frame, [0, 8], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const fadeOut = interpolate(frame, [FOOTAGE_FRAMES - 8, FOOTAGE_FRAMES], [1, 0], {
    extrapolateLeft: "clamp",
  });
  const progress = Math.min(1, frame / FOOTAGE_FRAMES);

  let offset = 0;
  return (
    <AbsoluteFill style={{ background: "#000", opacity: fadeIn * fadeOut }}>
      {STEPS.map((s) => {
        const dur = stepDuration(s);
        const from = offset;
        offset += dur;
        return (
          <Sequence key={s.num} from={from} durationInFrames={dur}>
            <StepBlock step={s} />
          </Sequence>
        );
      })}
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
        <FootageSection />
      </Sequence>
      <Sequence from={INTRO_FRAMES + FOOTAGE_FRAMES} durationInFrames={OUTRO_FRAMES}>
        <OutroCard />
      </Sequence>
    </AbsoluteFill>
  );
};
