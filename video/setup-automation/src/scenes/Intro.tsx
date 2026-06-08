import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  Easing,
} from "remotion";
import { fontFamily, brand } from "../theme";

export const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoIn = spring({ frame, fps, config: { damping: 14, mass: 0.8 } });
  const titleOpacity = interpolate(frame, [10, 28], [0, 1], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const titleY = interpolate(titleOpacity, [0, 1], [40, 0]);
  const subOpacity = interpolate(frame, [22, 40], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: `radial-gradient(120% 90% at 50% 18%, #16315e 0%, ${brand.bgPrimary} 60%, #05070f 100%)`,
        fontFamily,
        alignItems: "center",
        justifyContent: "center",
        padding: 80,
      }}
    >
      <div
        style={{
          transform: `scale(${interpolate(logoIn, [0, 1], [0.4, 1])})`,
          opacity: logoIn,
          width: 280,
          height: 280,
          borderRadius: 70,
          background: `linear-gradient(150deg, ${brand.accent}, #6E9BFF)`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          boxShadow: `0 30px 90px ${brand.accent}66`,
          marginBottom: 70,
        }}
      >
        {/* wave / pulse mark */}
        <svg width="170" height="170" viewBox="0 0 100 100" fill="none">
          <path
            d="M6 56h16l10-30 16 50 12-34 8 16h20"
            stroke="#fff"
            strokeWidth={7}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </div>

      <div
        style={{
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
          color: "#fff",
          fontSize: 92,
          fontWeight: 800,
          textAlign: "center",
          lineHeight: 1.05,
        }}
      >
        Set Up Auto-Tracking
      </div>
      <div
        style={{
          opacity: subOpacity,
          color: "rgba(255,255,255,0.7)",
          fontSize: 44,
          fontWeight: 500,
          textAlign: "center",
          marginTop: 34,
          maxWidth: 820,
          lineHeight: 1.35,
        }}
      >
        Log every Apple Wallet tap automatically — in about a minute.
      </div>
    </AbsoluteFill>
  );
};
