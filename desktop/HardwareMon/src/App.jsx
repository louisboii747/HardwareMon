import { motion } from "framer-motion";
import {
  Cpu,
  MemoryStick,
  HardDrive,
  Activity,
  Network,
  Settings,
  Thermometer,
} from "lucide-react";

function SidebarItem({ icon, label, active }) {
  return (
    <motion.div
      whileHover={{ x: 4 }}
      whileTap={{ scale: 0.98 }}
      className={`
        flex items-center gap-3 px-4 py-3 rounded-2xl cursor-pointer
        transition-all duration-300
        ${
          active
            ? "bg-blue-500/20 text-blue-400 border border-blue-500/20"
            : "text-gray-400 hover:bg-white/5 hover:text-white"
        }
      `}
    >
      {icon}
      <span className="font-medium">{label}</span>
    </motion.div>
  );
}

function StatCard({ icon, title, value, color }) {
  return (
    <motion.div
      whileHover={{
        scale: 1.02,
        y: -4,
      }}
      transition={{
        type: "spring",
        stiffness: 260,
      }}
      className="
        relative overflow-hidden
        bg-white/5 backdrop-blur-xl
        border border-white/10
        rounded-3xl
        p-6
        shadow-2xl
      "
    >
      {/* Glow */}
      <div
        className={`absolute top-0 right-0 w-32 h-32 blur-3xl opacity-20 ${color}`}
      />

      <div className="relative z-10">
        <div className="flex items-center gap-3 mb-6">
          <div className="text-blue-400">
            {icon}
          </div>

          <h2 className="text-lg font-semibold">
            {title}
          </h2>
        </div>

        <p className="text-5xl font-bold tracking-tight">
          {value}
        </p>
      </div>
    </motion.div>
  );
}

export default function App() {
  return (
    <div className="flex min-h-screen bg-[#070b14] text-white">

      {/* Sidebar */}
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

        <div className="space-y-2">
          <SidebarItem
            icon={<Activity size={20} />}
            label="Dashboard"
            active
          />

          <SidebarItem
            icon={<Cpu size={20} />}
            label="CPU"
          />

          <SidebarItem
            icon={<MemoryStick size={20} />}
            label="Memory"
          />

          <SidebarItem
            icon={<HardDrive size={20} />}
            label="Storage"
          />

          <SidebarItem
            icon={<Thermometer size={20} />}
            label="Temperatures"
          />

          <SidebarItem
            icon={<Network size={20} />}
            label="Network"
          />

          <SidebarItem
            icon={<Settings size={20} />}
            label="Settings"
          />
        </div>
      </aside>

      {/* Main */}
      <main className="flex-1 p-10">

        {/* Header */}
        <div className="mb-10">
          <motion.h2
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-5xl font-bold tracking-tight"
          >
            Dashboard
          </motion.h2>

          <p className="text-gray-400 mt-3 text-lg">
            Real-time system overview
          </p>
        </div>

        {/* Cards */}
        <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">

          <StatCard
            icon={<Cpu size={30} />}
            title="CPU Usage"
            value="32%"
            color="bg-blue-500"
          />

          <StatCard
            icon={<MemoryStick size={30} />}
            title="Memory"
            value="14.2 GB"
            color="bg-purple-500"
          />

          <StatCard
            icon={<HardDrive size={30} />}
            title="Disk Usage"
            value="58%"
            color="bg-cyan-500"
          />

        </div>
      </main>
    </div>
  );
}
