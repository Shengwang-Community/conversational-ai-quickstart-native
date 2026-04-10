export function generateRandomChannelName(platform: string = 'harmony'): string {
  const suffix = Math.floor(Math.random() * 900000) + 100000;
  return `channel_${platform}_${suffix}`;
}
