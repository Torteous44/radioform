import HomeClient from "@/components/HomeClient";
import Folder from "@/components/Folder";
import Card from "@/components/Card";
import Logs from "@/components/Logs";
import Instructions from "@/components/Instructions";
import TexturePreloader from "@/components/TexturePreloader";

export default function Home() {
  return (
    <TexturePreloader>
      <HomeClient
        card={<Card />}
        logs={<Logs />}
        instructions={<Instructions />}
        folder={<Folder />}
      />
    </TexturePreloader>
  );
}
