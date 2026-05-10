import { Cpu, MemoryStick, HardDrive } from "lucide-react";
import { motion } from "framer-motion";

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

export default function Dashboard() {
  return (
    <>
      <div className="mb-10">
        <h2 className="text-5xl font-bold tracking-tight">
          Dashboard
        </h2>

        <p className="text-gray-400 mt-3 text-lg">
          Real-time system overview
        </p>
      </div>

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
    </>
  );
}