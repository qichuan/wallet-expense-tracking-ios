import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { fontFamily, ios, brand } from "../theme";
import { StatusBar } from "../components/StatusBar";
import { Caption } from "../components/Caption";
import { Highlight } from "../components/Highlight";
import { TapRing } from "../components/TapRing";
import { Screen, Group, Checkmark, Toggle } from "../components/ui";

const TAP1 = 30; // tap Run Immediately
const TAP2 = 78; // tap Next

const RowLine: React.FC<{
  title: string;
  trailing?: React.ReactNode;
  last?: boolean;
}> = ({ title, trailing, last }) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      height: 124,
      padding: "0 36px",
      borderBottom: last ? "none" : `1px solid ${ios.separator}`,
      fontFamily,
    }}
  >
    <div style={{ flex: 1, color: "#fff", fontSize: 40 }}>{title}</div>
    {trailing}
  </div>
);

const RUN_X = 56;
const RUN_Y = 540;
const RUN_W = 968;
const RUN_H = 124;

const NEXT_X = 832;
const NEXT_Y = 150;
const NEXT_W = 168;
const NEXT_H = 84;

export const S5RunImmediately: React.FC = () => {
  const frame = useCurrentFrame();
  const checkOpacity = interpolate(frame, [TAP1, TAP1 + 8], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <Screen>
      <StatusBar />

      <div
        style={{
          position: "absolute",
          top: 150,
          left: 56,
          color: ios.blue,
        }}
      >
        <svg width="26" height="44" viewBox="0 0 26 44" fill="none">
          <path d="M22 6 8 22l14 16" stroke={ios.blue} strokeWidth={5} strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </div>
      <div
        style={{
          position: "absolute",
          top: 150,
          left: 0,
          right: 0,
          textAlign: "center",
          fontSize: 36,
          fontWeight: 700,
          color: "#fff",
          fontFamily,
          height: 84,
          lineHeight: "84px",
        }}
      >
        Wallet Automation
      </div>
      <div
        style={{
          position: "absolute",
          top: NEXT_Y,
          left: NEXT_X,
          width: NEXT_W,
          height: NEXT_H,
          background: ios.blue,
          color: "#fff",
          borderRadius: 42,
          fontSize: 38,
          fontWeight: 600,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontFamily,
        }}
      >
        Next
      </div>

      <div
        style={{
          position: "absolute",
          top: 330,
          left: 56,
          color: ios.textSecondary,
          fontSize: 32,
          fontFamily,
          lineHeight: 1.3,
        }}
      >
        Choose how this automation runs.
      </div>

      <div style={{ position: "absolute", top: 430, left: 56, right: 56 }}>
        <Group>
          <RowLine title="Run After Confirmation" trailing={<div style={{ width: 40 }} />} />
          <RowLine
            title="Run Immediately"
            trailing={<div style={{ opacity: checkOpacity }}><Checkmark /></div>}
          />
          <RowLine title="Notify When Run" trailing={<Toggle on={false} />} last />
        </Group>
      </div>

      <Highlight x={RUN_X} y={RUN_Y} width={RUN_W} height={RUN_H} radius={20} at={8} color={brand.gold} />
      <TapRing x={540} y={RUN_Y + RUN_H / 2} at={TAP1} />

      <Highlight x={NEXT_X} y={NEXT_Y} width={NEXT_W} height={NEXT_H} radius={42} at={TAP2 - 14} color={brand.gold} />
      <TapRing x={NEXT_X + NEXT_W / 2} y={NEXT_Y + NEXT_H / 2} at={TAP2} />

      <Caption step={5} total={7} text="Turn on Run Immediately, then tap Next" />
    </Screen>
  );
};
