import React from "react";
import { interpolate, useCurrentFrame } from "remotion";
import { fontFamily, ios, brand } from "../theme";
import { StatusBar } from "../components/StatusBar";
import { Caption } from "../components/Caption";
import { TapRing } from "../components/TapRing";
import { Screen } from "../components/ui";

const TAPS = [22, 54, 86]; // Merchant, Amount, Card

const CARD_TOP = 470;
const CARD_PAD = 40;
const HEADER_H = 104;
const ROW_H = 150;

const FIELDS = [
  { connector: "from", name: "Merchant", tap: TAPS[0] },
  { connector: "for", name: "Amount", tap: TAPS[1] },
  { connector: "using", name: "Card", tap: TAPS[2] },
];

const MagicGlyph: React.FC = () => (
  <svg width="30" height="30" viewBox="0 0 24 24" fill="none">
    <path
      d="M5 3l1.2 3L9 7l-2.8 1L5 11 3.8 8 1 7l2.8-1L5 3zM17 9l1.6 4 4 1.6-4 1.6L17 20l-1.6-3.8-4-1.6 4-1.6L17 9z"
      fill="#fff"
    />
  </svg>
);

const ParamRow: React.FC<{
  connector: string;
  name: string;
  tap: number;
  last?: boolean;
}> = ({ connector, name, tap, last }) => {
  const frame = useCurrentFrame();
  const fill = interpolate(frame, [tap, tap + 8], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const filled = fill > 0.5;

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        height: ROW_H,
        borderBottom: last ? "none" : `1px solid ${ios.separator}`,
        gap: 24,
        fontFamily,
      }}
    >
      <div style={{ color: "#fff", fontSize: 40, fontWeight: 500, width: 230 }}>
        {connector}{" "}
        <span style={{ color: ios.textSecondary }}>({name})</span>
      </div>
      <div style={{ flex: 1, display: "flex", justifyContent: "flex-end" }}>
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 12,
            padding: "14px 26px",
            borderRadius: 18,
            fontSize: 38,
            fontWeight: 600,
            transform: `scale(${interpolate(fill, [0, 0.5, 1], [1, 1.1, 1])})`,
            background: filled ? brand.accent : "transparent",
            border: filled
              ? `2px solid ${brand.accent}`
              : `3px dashed ${ios.textTertiary}`,
            color: filled ? "#fff" : ios.textTertiary,
            whiteSpace: "nowrap",
          }}
        >
          {filled ? (
            <>
              <MagicGlyph />
              Shortcut Input
            </>
          ) : (
            "Choose…"
          )}
        </div>
      </div>
    </div>
  );
};

const StepDot: React.FC<{ label: string; tap: number }> = ({ label, tap }) => {
  const frame = useCurrentFrame();
  const done = frame >= tap + 8;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 18, fontFamily }}>
      <div
        style={{
          width: 50,
          height: 50,
          borderRadius: "50%",
          background: done ? brand.green : ios.groupBg2,
          color: "#fff",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontSize: 30,
        }}
      >
        {done ? "✓" : ""}
      </div>
      <div style={{ color: done ? "#fff" : ios.textSecondary, fontSize: 36 }}>
        {label}
      </div>
    </div>
  );
};

export const S7MapInputs: React.FC = () => {
  const frame = useCurrentFrame();

  const rowCenterY = (i: number) =>
    CARD_TOP + CARD_PAD + HEADER_H + i * ROW_H + ROW_H / 2;
  const activeTap = TAPS.reduce(
    (acc, t, i) => (frame >= t && frame < t + 20 ? i : acc),
    -1,
  );

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
        Wallet Automation
      </div>

      <div
        style={{
          position: "absolute",
          top: 320,
          left: 56,
          right: 56,
          color: ios.textSecondary,
          fontSize: 32,
          fontFamily,
        }}
      >
        Fill each field from the Wallet tap.
      </div>

      {/* Action card */}
      <div
        style={{
          position: "absolute",
          top: CARD_TOP,
          left: 56,
          right: 56,
          background: ios.groupBg,
          borderRadius: 32,
          padding: `${CARD_PAD}px 40px`,
          fontFamily,
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 18,
            height: HEADER_H,
            color: "#fff",
            fontSize: 40,
            fontWeight: 600,
            borderBottom: `1px solid ${ios.separator}`,
          }}
        >
          <div
            style={{
              width: 56,
              height: 56,
              borderRadius: 14,
              background: brand.accent,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 30,
            }}
          >
            💳
          </div>
          Log Transaction
        </div>
        {FIELDS.map((f, i) => (
          <ParamRow
            key={f.name}
            connector={f.connector}
            name={f.name}
            tap={f.tap}
            last={i === FIELDS.length - 1}
          />
        ))}
      </div>

      {/* Checklist */}
      <div
        style={{
          position: "absolute",
          top: 1240,
          left: 80,
          display: "flex",
          flexDirection: "column",
          gap: 30,
        }}
      >
        <StepDot label="Merchant → Shortcut Input" tap={TAPS[0]} />
        <StepDot label="Amount → Shortcut Input" tap={TAPS[1]} />
        <StepDot label="Card → Shortcut Input" tap={TAPS[2]} />
      </div>

      {activeTap >= 0 ? (
        <TapRing x={770} y={rowCenterY(activeTap)} at={TAPS[activeTap]} />
      ) : null}

      <Caption
        step={7}
        total={7}
        text="Set each field to the Wallet's Shortcut Input"
      />
    </Screen>
  );
};
