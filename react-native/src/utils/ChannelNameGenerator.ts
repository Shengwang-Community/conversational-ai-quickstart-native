export function generateRandomChannelName(
  platform: string = 'reactnative',
): string {
  const random = Math.floor(Math.random() * 900000) + 100000;
  return `channel_${platform}_${random}`;
}
