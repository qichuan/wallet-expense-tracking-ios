import React from "react";
import { fontFamily, ios, brand } from "../theme";
import { StatusBar } from "../components/StatusBar";
import { Caption } from "../components/Caption";
import { Highlight } from "../components/Highlight";
import { TapRing } from "../components/TapRing";
import { Screen, PillButton } from "../components/ui";

const TabItem: React.FC<{
  label: string;
  active?: boolean;
  icon: React.ReactNode;
}> = ({ label, active, icon }) => (
  <div
    style={{
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 8,
      color: active ? ios.blue : ios.textSecondary,
      fontSize: 24,
      flex: 1,
    }}
  >
    {icon}
    {label}
  </div>
);

const BTN_X = 348;
const BTN_Y = 1230;
const BTN_W = 384;
const BTN_H = 96;

export const S2NewAutomation: React.FC = () => {
  return (
    <Screen>
      <StatusBar />

      <div
        style={{
          position: "absolute",
          top: 130,
          left: 56,
          fontSize: 66,
          fontWeight: 800,
          color: "#fff",
          fontFamily,
        }}
      >
        Automation
      </div>

      {/* Empty state */}
      <div
        style={{
          position: "absolute",
          top: 980,
          left: 0,
          right: 0,
          textAlign: "center",
          fontFamily,
        }}
      >
        <div style={{ fontSize: 90, marginBottom: 10 }}>✦</div>
        <div style={{ color: "#fff", fontSize: 44, fontWeight: 700 }}>
          No Automations
        </div>
        <div style={{ color: ios.textSecondary, fontSize: 32, marginTop: 10 }}>
          Make shortcuts run automatically.
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          left: BTN_X,
          top: BTN_Y,
        }}
      >
        <PillButton label="New Automation" style={{ fontSize: 38, padding: "26px 50px" }} />
      </div>

      {/* Tab bar */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          height: 170,
          background: "rgba(28,28,30,0.92)",
          borderTop: `1px solid ${ios.separator}`,
          display: "flex",
          alignItems: "flex-start",
          paddingTop: 24,
          fontFamily,
        }}
      >
        <TabItem
          label="Library"
          icon={
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none">
              <rect x="3" y="4" width="18" height="14" rx="2" stroke="currentColor" strokeWidth="2" />
            </svg>
          }
        />
        <TabItem
          label="Automation"
          active
          icon={
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2" />
              <path d="M12 7v5l3 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
          }
        />
        <TabItem
          label="Gallery"
          icon={
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none">
              {[0, 1].map((r) =>
                [0, 1].map((c) => (
                  <rect key={`${r}${c}`} x={4 + c * 9} y={4 + r * 9} width="7" height="7" rx="1.5" stroke="currentColor" strokeWidth="2" />
                )),
              )}
            </svg>
          }
        />
      </div>

      <Highlight x={BTN_X} y={BTN_Y} width={BTN_W} height={BTN_H} radius={48} at={8} color={brand.gold} />
      <TapRing x={BTN_X + BTN_W / 2} y={BTN_Y + BTN_H / 2} at={42} />

      <Caption step={2} total={7} text="Tap New Automation" />
    </Screen>
  );
};
