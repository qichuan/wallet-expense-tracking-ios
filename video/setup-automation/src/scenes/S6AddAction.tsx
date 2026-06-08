import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { fontFamily, ios, brand } from "../theme";
import { StatusBar } from "../components/StatusBar";
import { Caption } from "../components/Caption";
import { Highlight } from "../components/Highlight";
import { TapRing } from "../components/TapRing";
import { Screen } from "../components/ui";

const QUERY = "Log transaction";
const TYPE_START = 8;
const TYPE_END = 42;
const RESULT_AT = 40;
const TAP = 72;

const ROW_X = 56;
const ROW_Y = 560;
const ROW_W = 968;
const ROW_H = 176;

const CardPulseIcon: React.FC<{ size: number }> = ({ size }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: size * 0.26,
      background: `linear-gradient(150deg,${brand.accent},#6E9BFF)`,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      flexShrink: 0,
    }}
  >
    <svg width={size * 0.62} height={size * 0.62} viewBox="0 0 100 100" fill="none">
      <path
        d="M8 56h14l9-26 15 46 11-30 7 14h18"
        stroke="#fff"
        strokeWidth={8}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  </div>
);

export const S6AddAction: React.FC = () => {
  const frame = useCurrentFrame();
  const chars = Math.round(
    interpolate(frame, [TYPE_START, TYPE_END], [0, QUERY.length], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }),
  );
  const typed = QUERY.slice(0, chars);
  const caretOn = Math.floor(frame / 8) % 2 === 0;

  const resultOpacity = interpolate(frame, [RESULT_AT, RESULT_AT + 10], [0, 1], {
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
        New Shortcut
      </div>

      <div
        style={{
          position: "absolute",
          top: 300,
          left: 0,
          right: 0,
          textAlign: "center",
          color: ios.textSecondary,
          fontSize: 32,
          fontFamily,
        }}
      >
        Search for an action to add.
      </div>

      {/* Search field */}
      <div
        style={{
          position: "absolute",
          top: 400,
          left: 56,
          right: 56,
          height: 92,
          background: ios.groupBg2,
          borderRadius: 24,
          display: "flex",
          alignItems: "center",
          gap: 18,
          padding: "0 28px",
          fontFamily,
        }}
      >
        <svg width="34" height="34" viewBox="0 0 24 24" fill="none">
          <circle cx="11" cy="11" r="7" stroke={ios.textSecondary} strokeWidth="2.4" />
          <path d="M16.5 16.5 21 21" stroke={ios.textSecondary} strokeWidth="2.4" strokeLinecap="round" />
        </svg>
        <div style={{ color: "#fff", fontSize: 38, display: "flex", alignItems: "center" }}>
          {typed.length ? typed : <span style={{ color: ios.textTertiary }}>Search Actions</span>}
          {caretOn && chars < QUERY.length && chars > 0 ? (
            <span style={{ color: ios.blue, marginLeft: 2 }}>|</span>
          ) : null}
        </div>
      </div>

      {/* Result row */}
      <div
        style={{
          position: "absolute",
          top: ROW_Y,
          left: ROW_X,
          width: ROW_W,
          opacity: resultOpacity,
        }}
      >
        <div
          style={{
            background: ios.groupBg,
            borderRadius: 28,
            padding: "32px 32px",
            display: "flex",
            alignItems: "center",
            gap: 28,
            fontFamily,
          }}
        >
          <CardPulseIcon size={92} />
          <div style={{ flex: 1 }}>
            <div style={{ color: "#fff", fontSize: 40, fontWeight: 600 }}>
              Log Transaction
            </div>
            <div style={{ color: ios.textSecondary, fontSize: 30, marginTop: 8 }}>
              CardPulse
            </div>
          </div>
          <div
            style={{
              width: 56,
              height: 56,
              borderRadius: "50%",
              background: brand.accent,
              color: "#fff",
              fontSize: 44,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              lineHeight: 1,
            }}
          >
            +
          </div>
        </div>
      </div>

      <Highlight x={ROW_X} y={ROW_Y} width={ROW_W} height={ROW_H} radius={28} at={RESULT_AT + 6} color={brand.gold} />
      <TapRing x={540} y={ROW_Y + ROW_H / 2} at={TAP} />

      <Caption step={6} total={7} text='Search "Log Transaction" and add the CardPulse action' />
    </Screen>
  );
};
