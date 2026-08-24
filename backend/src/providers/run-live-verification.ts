import { verifyAllProvidersLive } from './provider-live-verification.js';

async function main() {
    console.log('Starting PayMuster live provider verification...');
    const results = await verifyAllProvidersLive();
    console.log(JSON.stringify(results, null, 2));
}

main().catch((err) => {
    console.error('Fatal verification error:', err);
    process.exit(1);
});
