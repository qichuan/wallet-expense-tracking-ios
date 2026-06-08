import React from "react";
import { AbsoluteFill } from "remotion";
import { fontFamily } from "../theme";
import { StatusBar } from "../components/StatusBar";
import { Caption } from "../components/Caption";
import { Highlight } from "../components/Highlight";
import { TapRing } from "../components/TapRing";
import { AppIcon } from "../components/ui";

const ShortcutsIcon: React.FC<{ size: number }> = ({ size }) => (
  <AppIcon
    size={size}
    gradient="linear-gradient(150deg,#2A2A72,#C44BC4 55%,#F06CA8)"
  >
    <svg width={size * 0.62} height={size * 0.62} viewBox="0 0 100 100">
      <path
        d="M30 28a16 16 0 1 1 18 24 16 16 0 1 0 18 24"
        stroke="#fff"
        strokeWidth={11}
        strokeLinecap="round"
        fill="none"
        opacity={0.95}
      />
    </svg>
  </AppIcon>
);

const ICON = 196;
const IX = 90; // left of icon
const IY = 360; // top of icon

export const S1Home: React.FC = () => {
  return (
    <AbsoluteFill
      style={{
        background:
          "linear-gradient(180deg,#d24d86 0%,#c43f74 45%,#a82f5e 100%)",
        fontFamily,
      }}
    >
      <StatusBar />

      {/* App grid (just Shortcuts, top-left) */}
      <div style={{ position: "absolute", left: IX, top: IY }}>
        <ShortcutsIcon size={ICON} />
        <div
          style={{
            color: "#fff",
            fontSize: 30,
            textAlign: "center",
            marginTop: 14,
            width: ICON,
            textShadow: "0 1px 4px rgba(0,0,0,0.4)",
          }}
        >
          Shortcuts
        </div>
      </div>

      {/* Search pill */}
      <div
        style={{
          position: "absolute",
          left: "50%",
          transform: "translateX(-50%)",
          bottom: 360,
          background: "rgba(255,255,255,0.22)",
          color: "rgba(255,255,255,0.9)",
          fontSize: 30,
          padding: "16px 40px",
          borderRadius: 30,
          display: "flex",
          alignItems: "center",
          gap: 14,
        }}
      >
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
          <circle cx="11" cy="11" r="7" stroke="#fff" strokeWidth="2.4" />
          <path
            d="M16.5 16.5 21 21"
            stroke="#fff"
            strokeWidth="2.4"
            strokeLinecap="round"
          />
        </svg>
        Search
      </div>

      <Highlight
        x={IX}
        y={IY}
        width={ICON}
        height={ICON}
        radius={46}
        at={8}
      />
      <TapRing x={IX + ICON / 2} y={IY + ICON / 2} at={40} />

      <Caption step={1} total={7} text="Open the Shortcuts app" />
    </AbsoluteFill>
  );
};
