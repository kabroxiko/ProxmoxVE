import type { MetadataRoute } from "next";

import { basePath } from "@/config/site-config";

export const dynamic = "force-static";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const domain = "localhost:3000";
  const protocol = "http";
  return [
    {
      url: `${protocol}://${domain}/${basePath}`,
      lastModified: new Date(),
    },
    {
      url: `${protocol}://${domain}/${basePath}/scripts`,
      lastModified: new Date(),
    },
    {
      url: `${protocol}://${domain}/${basePath}/json-editor`,
      lastModified: new Date(),
    },
  ];
}
