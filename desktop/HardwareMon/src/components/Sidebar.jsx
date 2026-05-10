import { motion } from "framer-motion";
import {
  Activity,
  Cpu,
  MemoryStick,
  HardDrive,
  Thermometer,
  Network,
 Settings
} from "lucide-react";

import { NavLink } from "react-router-dom";

function SidebarItem({ to, icon, label }) {
  return (
    <NavLink to={to}>
      {({ isActive }) => (
        <motion.div
          whileHover={{ x: 4 }}
          whileTap={{ scale: 0.98 }}
          className={`
            flex items-center gap-3 px-4 py-3 rounded-2xl cursor-pointer
            transition-all duration-300 mb-2
            ${
              isActive
                ? "bg-blue-500/20 text-blue-400 border border-blue-500/20"
                : "text-gray-400 hover:bg-white/5 hover:text-white"
            }
          `}
        >
          {icon}
          <span className="font-medium">{label}</span>
        </motion.div>
      )}
    </NavLink>
  );
}

export default function Sidebar() {
  return (
    <aside className="
      w-72
      bg-white/5
      backdrop-blur-2xl
      border-r border-white/10
      p-5
    ">
      <div className="mb-10">
        <h1 className="text-3xl font-bold tracking-tight">
          HardwareMon
        </h1>

        <p className="text-gray-400 mt-2 text-sm">
          Modern hardware monitoring
        </p>
      </div>

      <div>
        <SidebarItem
          to="/"
          icon={<Activity size={20} />}
          label="Dashboard"
        />

        <SidebarItem
          to="/cpu"
          icon={<Cpu size={20} />}
          label="CPU"
        />

        <SidebarItem
          to="/memory"
          icon={<MemoryStick size={20} />}
          label="Memory"
        />

        <SidebarItem
          to="/storage"
          icon={<HardDrive size={20} />}
          label="Storage"
        />

        <SidebarItem
          to="/temperatures"
          icon={<Thermometer size={20} />}
          label="Temperatures"
        />

        <SidebarItem
          to="/network"
          icon={<Network size={20} />}
          label="Network"
        />

        <SidebarItem
          to="/settings"
          icon={<Settings size={20} />}
          label="Settings"
        />
      </div>
    </aside>
  );
}