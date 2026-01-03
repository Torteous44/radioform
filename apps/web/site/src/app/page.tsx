import HomeClient from "@/components/HomeClient";
import Folder from "@/components/Folder";
import Card from "@/components/Card";
import Logs from "@/components/Logs";
import Instructions from "@/components/Instructions";

export default function Home() {
  return (
    <HomeClient
      card={<Card />}
      logs={<Logs />}
      instructions={<Instructions />}
      folder={<Folder />}
    />
  );
}
