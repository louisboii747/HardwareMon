import {
  BrowserRouter,
  Routes,
  Route
} from "react-router-dom";

import MainLayout from "./layouts/MainLayout";
import Dashboard from "./pages/Dashboard";

function Placeholder({ title }) {
  return (
    <div>
      <h1 className="text-5xl font-bold">
        {title}
      </h1>
    </div>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <MainLayout>
        <Routes>

          <Route
            path="/"
            element={<Dashboard />}
          />

          <Route
            path="/cpu"
            element={<Placeholder title="CPU" />}
          />

          <Route
            path="/memory"
            element={<Placeholder title="Memory" />}
          />

          <Route
            path="/storage"
            element={<Placeholder title="Storage" />}
          />

          <Route
            path="/temperatures"
            element={<Placeholder title="Temperatures" />}
          />

          <Route
            path="/network"
            element={<Placeholder title="Network" />}
          />

          <Route
            path="/settings"
            element={<Placeholder title="Settings" />}
          />

        </Routes>
      </MainLayout>
    </BrowserRouter>
  );
}