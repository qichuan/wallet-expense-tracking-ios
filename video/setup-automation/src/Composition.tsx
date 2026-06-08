import React from "react";
import {
  AbsoluteFill,
  Sequence,
  interpolate,
  useCurrentFrame,
} from "remotion";
import { Intro } from "./scenes/Intro";
import { S1Home } from "./scenes/S1Home";
import { S2NewAutomation } from "./scenes/S2NewAutomation";
import { S3ChooseWallet } from "./scenes/S3ChooseWallet";
import { S4SelectCards } from "./scenes/S4SelectCards";
import { S5RunImmediately } from "./scenes/S5RunImmediately";
import { S6AddAction } from "./scenes/S6AddAction";
import { S7MapInputs } from "./scenes/S7MapInputs";
import { Outro } from "./scenes/Outro";

const FADE = 7;

const SceneWrap: React.FC<{
  duration: number;
  children: React.ReactNode;
}> = ({ duration, children }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [0, FADE, duration - FADE, duration],
    [0, 1, 1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  return (
    <AbsoluteFill style={{ opacity, background: "#000" }}>
      {children}
    </AbsoluteFill>
  );
};

const SCENES: { c: React.FC; d: number }[] = [
  { c: Intro, d: 78 },
  { c: S1Home, d: 84 },
  { c: S2NewAutomation, d: 80 },
  { c: S3ChooseWallet, d: 108 },
  { c: S4SelectCards, d: 92 },
  { c: S5RunImmediately, d: 112 },
  { c: S6AddAction, d: 108 },
  { c: S7MapInputs, d: 132 },
  { c: Outro, d: 86 },
];

export const SETUP_DURATION = SCENES.reduce((a, s) => a + s.d, 0);

export const SetupAutomation: React.FC = () => {
  let offset = 0;
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      {SCENES.map((s, i) => {
        const from = offset;
        offset += s.d;
        const Comp = s.c;
        return (
          <Sequence key={i} from={from} durationInFrames={s.d}>
            <SceneWrap duration={s.d}>
              <Comp />
            </SceneWrap>
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};
