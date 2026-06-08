import React from "react";
import {
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { fontFamily, brand } from "../theme";

// Bottom caption banner that names the step and the action to perform.
export const Caption: React.FC<{
  step: number;
  total: number;
  text: string;
}> = ({ step, total, text }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const appear = interpolate(frame, [0, 0.4 * fps], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const y = interpolate(appear, [0, 1], [60, 0]);

  return (
    <div
      style={{
        position: "absolute",
        bottom: 90,
        left: 56,
        right: 56,
        zIndex: 40,
        opacity: appear,
        transform: `translateY(${y}px)`,
        fontFamily,
      }}
    >
      <div
        style={{
          background: "rgba(14,22,42,0.86)",
          backdropFilter: "blur(12px)",
          border: `1px solid ${brand.accent}55`,
          borderRadius: 38,
          padding: "34px 40px",
          display: "flex",
          alignItems: "center",
          gap: 30,
          boxShadow: "0 20px 60px rgba(0,0,0,0.55)",
        }}
      >
        <div
          style={{
            flexShrink: 0,
            width: 88,
            height: 88,
            borderRadius: "50%",
            background: brand.accent,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            color: "#fff",
            lineHeight: 1,
          }}
        >
          <div style={{ fontSize: 40, fontWeight: 800 }}>{step}</div>
          <div style={{ fontSize: 18, opacity: 0.8, marginTop: 3 }}>
            / {total}
          </div>
        </div>
        <div
          style={{
            color: "#fff",
            fontSize: 40,
            fontWeight: 600,
            lineHeight: 1.25,
          }}
        >
          {text}
        </div>
      </div>
    </div>
  );
};
