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
import { CaptionStrip, FootageTap, ScrollHint, ActionType } from "./parts";
import { IntroCard, OutroCard } from "./Bookends";

// ---- Geometry ----
export const VIDEO_W = 720;
export const VIDEO_H = 1558; // source footage height
export const STRIP_H = 240;
export const COMP_W = VIDEO_W;
export const COMP_H = VIDEO_H + STRIP_H; // 1798

export const INTRO_FRAMES = 42;
export const OUTRO_FRAMES = 80;

const FPS = 30;
const SRC = "Setup-Automation.mp4";
const TOTAL_STEPS = 9;

type Tap = { x: number; y: number; t: number }; // t = source seconds

type Step = {
  num: number;
  text: string;
  action: ActionType;
  fromSec: number; // source segment played during this step
  toSec: number;
  pause: number; // read-hold frames before the segment plays
  taps: Tap[];
  scrollHint?: boolean;
};

// Each step: hold on its first frame (so the instruction can be read), then
// play that slice of the real recording at 1x with the tap highlight.
const STEPS: Step[] = [
  {
    num: 1,
    text: "Open Shortcuts, then tap New Automation",
    action: "tap",
    fromSec: 0.0,
    toSec: 2.4,
    pause: 60,
    taps: [
      { x: 277, y: 363, t: 0.35 },
      { x: 359, y: 977, t: 1.6 },
    ],
  },
  {
    num: 2,
    text: "Scroll down and choose Wallet",
    action: "scroll",
    fromSec: 2.4,
    toSec: 6.2,
    pause: 55,
    taps: [{ x: 360, y: 1175, t: 5.6 }],
    scrollHint: true,
  },
  {
    num: 3,
    text: "Keep all your cards & categories selected",
    action: "check",
    fromSec: 6.2,
    toSec: 9.2,
    pause: 60,
    taps: [],
  },
  {
    num: 4,
    text: "Scroll down and turn on Run Immediately",
    action: "scroll",
    fromSec: 9.2,
    toSec: 11.2,
    pause: 60,
    taps: [{ x: 250, y: 1290, t: 10.6 }],
    scrollHint: true,
  },
  {
    num: 5,
    text: "Tap Next",
    action: "tap",
    fromSec: 11.2,
    toSec: 12.6,
    pause: 50,
    taps: [{ x: 633, y: 157, t: 11.4 }],
  },
  {
    num: 6,
    text: "Search “CardPulse” and add Log Wallet Transaction",
    action: "tap",
    fromSec: 12.6,
    toSec: 21.3,
    pause: 75,
    taps: [{ x: 200, y: 413, t: 19.0 }],
  },
  {
    num: 7,
    text: "Tap the 1st field → Shortcut Input · Type Merchant",
    action: "tap",
    fromSec: 21.3,
    toSec: 27.4,
    pause: 80,
    taps: [{ x: 175, y: 498, t: 22.6 }],
  },
  {
    num: 8,
    text: "Next field → Shortcut Input · Type Amount",
    action: "tap",
    fromSec: 27.4,
    toSec: 33.8,
    pause: 75,
    taps: [{ x: 430, y: 500, t: 27.6 }],
  },
  {
    num: 9,
    text: "Last field → Shortcut Input · Type Card or Pass — done!",
    action: "done",
    fromSec: 33.8,
    toSec: 44.367,
    pause: 80,
    taps: [{ x: 235, y: 552, t: 34.0 }],
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
        <Freeze frame={fromFrame}>
          <OffthreadVideo src={staticFile(SRC)} muted style={videoStyle} />
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
      {step.scrollHint && playing ? <ScrollHint /> : null}
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
