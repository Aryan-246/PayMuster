import { prisma } from './src/lib/prisma.js';
import bcrypt from 'bcryptjs';
import { readFileSync } from 'fs';

const API_URL = 'http://localhost:4000/auth';
const TEST_EMAIL = 'prove.e2e@example.com';
const TEST_PASSWORD = 'Password123!';

async function makeRequest(method: string, path: string, body?: any, token?: string) {
  console.log(`\n=== HTTP REQUEST ===`);
  console.log(`Request URL: ${API_URL}${path}`);
  console.log(`HTTP Method: ${method}`);
  if (body) console.log(`Request Body: ${JSON.stringify(body, null, 2)}`);
  
  const headers: any = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  const status = res.status;
  const resBody = await res.text();
  
  console.log(`\n=== HTTP RESPONSE ===`);
  console.log(`Response Status: ${status}`);
  console.log(`Response Body: ${resBody}`);

  return { status, body: resBody ? JSON.parse(resBody) : null };
}

async function dumpUser(label: string) {
  const users = await prisma.user.findMany({ where: { email: TEST_EMAIL } });
  console.log(`\n--- [${label}] DUMP User Table for ${TEST_EMAIL} ---`);
  if (users.length === 0) {
    console.log('(no rows)');
  } else {
    for (const u of users) {
      console.log(`ID: ${u.id}`);
      console.log(`Email: ${u.email}`);
      console.log(`Password hash prefix: ${u.passwordHash?.substring(0, 7)}...`);
      console.log(`CreatedAt: ${u.createdAt.toISOString()}`);
    }
  }
  return users;
}

async function runE2E() {
  console.log('--- STARTING E2E HTTP PROOF ---');
  
  // Cleanup any old test runs
  const oldUsers = await prisma.user.findMany({ where: { email: TEST_EMAIL } });
  for (const ou of oldUsers) {
    await prisma.authOtp.deleteMany({ where: { userId: ou.id } });
    await prisma.session.deleteMany({ where: { userId: ou.id } });
    await prisma.user.delete({ where: { id: ou.id } });
  }
  
  // 1. Initial Signup
  console.log('\n>>> STEP 1: HTTP POST /auth/signup');
  await makeRequest('POST', '/signup', { email: TEST_EMAIL, password: TEST_PASSWORD, name: 'E2E User' });

  // 2. Bypass Email Verification for Testing
  console.log('\n>>> Bypassing OTP, manually verifying email in DB...');
  let users = await dumpUser('After Initial Signup');
  const user1Id = users[0].id;
  await prisma.user.update({ where: { id: user1Id }, data: { emailVerified: true } });


  // 4. Initial Login
  console.log('\n>>> STEP 3: HTTP POST /auth/login (Initial)');
  const loginRes1 = await makeRequest('POST', '/login', { email: TEST_EMAIL, password: TEST_PASSWORD, rememberMe: false });
  const token = loginRes1.body.accessToken;
  console.log(`\nSession created? ${!!loginRes1.body.session}`);
  console.log(`Token created? ${!!token}`);

  // 5. Delete Account via HTTP
  console.log('\n>>> STEP 4: HTTP DELETE /auth/account');
  await makeRequest('DELETE', '/account', undefined, token);

  // 6. DB Dump After Delete
  await dumpUser('After DELETE /auth/account');

  // 7. Register AGAIN via HTTP
  console.log('\n>>> STEP 5: HTTP POST /auth/signup (SECOND TIME, SAME EMAIL)');
  await makeRequest('POST', '/signup', { email: TEST_EMAIL, password: TEST_PASSWORD, name: 'E2E User 2' });

  // 8. DB Dump After Second Signup
  users = await dumpUser('After Second Signup');
  const user2Id = users[0].id;
  
  console.log(`\n>>> VERIFY IDs:`);
  console.log(`Old ID: ${user1Id}`);
  console.log(`New ID: ${user2Id}`);
  console.log(`Are they different? ${user1Id !== user2Id}`);

  // 9. Bypass Email Verification for Second User
  console.log('\n>>> Bypassing OTP, manually verifying email for second user in DB...');
  await prisma.user.update({ where: { id: user2Id }, data: { emailVerified: true } });


  // 11. Login Again
  console.log('\n>>> STEP 7: HTTP POST /auth/login (Second User)');
  const loginRes2 = await makeRequest('POST', '/login', { email: TEST_EMAIL, password: TEST_PASSWORD, rememberMe: false });

  console.log(`\nSession created? ${!!loginRes2.body?.session}`);
  console.log(`Token created? ${!!loginRes2.body?.accessToken}`);

  // Print exact bcrypt comparison details if requested
  const rawUser = await prisma.user.findFirst({ where: { email: TEST_EMAIL }, orderBy: { createdAt: 'desc' }});
  if (rawUser && rawUser.passwordHash) {
    const match = await bcrypt.compare(TEST_PASSWORD, rawUser.passwordHash);
    console.log(`\n>>> INTERNAL BCRYPT VERIFICATION`);
    console.log(`Matched user ID: ${rawUser.id}`);
    console.log(`Password hash prefix: ${rawUser.passwordHash.substring(0, 7)}...`);
    console.log(`bcrypt.compare result: ${match}`);
  }

  // To print backend logs, we will grep the tail of the backend task logs
}

runE2E().catch(console.error).finally(() => prisma.$disconnect());
