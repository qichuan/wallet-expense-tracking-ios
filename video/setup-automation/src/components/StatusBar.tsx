import React from "react";
import { fontFamily, ios } from "../theme";

export const StatusBar: React.FC<{ time?: string }> = ({ time = "9:41" }) => {
  return (
    <div
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        right: 0,
        height: 96,
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "0 64px",
        fontFamily,
        color: ios.textPrimary,
        zIndex: 5,
      }}
    >
      <div style={{ fontSize: 34, fontWeight: 600, letterSpacing: 0.5 }}>
        {time}
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
        {/* cellular */}
        <svg width="40" height="26" viewBox="0 0 40 26">
          {[8, 14, 20, 26].map((h, i) => (
            <rect
              key={i}
              x={i * 9}
              y={26 - h}
              width={6}
              height={h}
              rx={2}
              fill="#fff"
            />
          ))}
        </svg>
        {/* wifi */}
        <svg width="34" height="26" viewBox="0 0 34 26" fill="none">
          <path
            d="M17 6c6 0 11.5 2.4 15.5 6.3l-3.4 3.5C26 12.9 21.7 11 17 11S8 12.9 4.9 15.8L1.5 12.3C5.5 8.4 11 6 17 6z"
            fill="#fff"
          />
          <path
            d="M17 14c3.2 0 6.1 1.3 8.2 3.4l-8.2 8.2-8.2-8.2C10.9 15.3 13.8 14 17 14z"
            fill="#fff"
          />
        </svg>
        {/* battery */}
        <svg width="50" height="26" viewBox="0 0 50 26">
          <rect
            x={1}
            y={4}
            width={42}
            height={18}
            rx={5}
            stroke="#fff"
            strokeOpacity={0.5}
            strokeWidth={2}
            fill="none"
          />
          <rect x={4} y={7} width={34} height={12} rx={2.5} fill="#fff" />
          <rect x={45} y={10} width={3.5} height={6} rx={2} fill="#fff" />
        </svg>
      </div>
    </div>
  );
};
