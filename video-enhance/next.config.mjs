/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    serverActions: {
      // Videos can be large; permit up to ~500MB uploads to the local server.
      bodySizeLimit: "500mb",
    },
  },
};

export default nextConfig;
