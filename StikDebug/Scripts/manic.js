// manic.js - iOS 26 TXM JIT Support Script for Manic EMU Emulator
// Optimized for Manic EMU using Geode.js's infinite loop mode
// Features:
// 1. Only handles brk #0x69 (JIT memory mapping requests)
// 2. Keeps StikDebug connection alive indefinitely
// 3. Supports JIT memory requests for multiple code blocks

function littleEndianHexStringToNumber(hexStr) {
    const bytes = [];
    for (let i = 0; i < hexStr.length; i += 2) {
        bytes.push(parseInt(hexStr.substr(i, 2), 16));
    }
    let num = 0n;
    for (let i = 4; i >= 0; i--) {
        num = (num << 8n) | BigInt(bytes[i]);
    }
    return num;
}

function numberToLittleEndianHexString(num) {
    const bytes = [];
    for (let i = 0; i < 5; i++) {
        bytes.push(Number(num & 0xFFn));
        num >>= 8n;
    }
    while (bytes.length < 8) {
        bytes.push(0);
    }
    return bytes.map(b => b.toString(16).padStart(2, '0')).join('');
}

function littleEndianHexToU32(hexStr) {
    return parseInt(hexStr.match(/../g).reverse().join(''), 16);
}

function extractBrkImmediate(u32) {
    return (u32 >> 5) & 0xFFFF;
}

// Check if the instruction is a BRK instruction
// BRK instruction format: 0xD4200000 | (imm16 << 5)
// The upper 16 bits should be 0xD420
function isBrkInstruction(u32) {
    return (u32 >>> 16) === 0xD420;
}

// Format size into a human-readable format
function formatSize(size) {
    if (size >= 1024 * 1024) {
        return `${(size / (1024 * 1024)).toFixed(2)} MB`;
    } else if (size >= 1024) {
        return `${(size / 1024).toFixed(2)} KB`;
    }
    return `${size} bytes`;
}

log(`[Manic EMU] ========================================`);
log(`[Manic EMU] Manic EMU iOS 26 TXM JIT Support Script`);
log(`[Manic EMU] ========================================`);

let pid = get_pid();
log(`[Manic EMU] pid = ${pid}`);
let attachResponse = send_command(`vAttach;${pid.toString(16)}`);
log(`[Manic EMU] attach_response = ${attachResponse}`);

let validBreakpoints = 0;
let totalBreakpoints = 0;
let totalMemoryMapped = 0n;

// Track processed memory areas for debugging.
let mappedRegions = [];

// Infinite Loop - StikDebug Must Stay Connected in TXM Mode
// The Manic EMU emulator dynamically creates multiple code blocks, each of which needs to be marked as executable by StikDebug.
log(`[Manic EMU] Starting infinite loop - StikDebug will stay connected`);
log(`[Manic EMU] Waiting for JIT memory requests (brk #0x69)...`);

while (true) {
    totalBreakpoints++;
    
    let brkResponse = send_command(`c`);
    
    // Check Exception Types (metype)
    // metype:6 = EXC_BREAKPOINT
    let metypeMatch = /metype:(\d+)/.exec(brkResponse);
    let metype = metypeMatch ? parseInt(metypeMatch[1]) : -1;
    
    // If it's not a breakpoint exception, just continue (let the program handle it).
    if (metype !== 6 && metype !== -1) {
        log(`[Manic EMU] Non-breakpoint exception (metype=${metype}), continuing...`);
        continue;
    }
    
    let tidMatch = /T[0-9a-f]+thread:(?<tid>[0-9a-f]+);/.exec(brkResponse);
    let tid = tidMatch ? tidMatch.groups['tid'] : null;
    let pcMatch = /20:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
    let pc = pcMatch ? pcMatch.groups['reg'] : null;
    let x0Match = /00:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
    let x0 = x0Match ? x0Match.groups['reg'] : null;
    let x1Match = /01:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
    let x1 = x1Match ? x1Match.groups['reg'] : null;
    
    if (!tid || !pc || !x0) {
        log(`[Manic EMU] Failed to extract registers, continuing...`);
        continue;
    }

    const pcNum = littleEndianHexStringToNumber(pc);
    const x0Num = littleEndianHexStringToNumber(x0);
    const x1Num = x1 ? littleEndianHexStringToNumber(x1) : 0n;
    
    let instructionResponse = send_command(`m${pcNum.toString(16)},4`);
    let instrU32 = littleEndianHexToU32(instructionResponse);
    
    // Check if it's a BRK instruction.
    if (!isBrkInstruction(instrU32)) {
        // Not a BRK instruction, skip it.
        log(`[Manic EMU] Not a BRK instruction at PC=0x${pcNum.toString(16)}, skipping...`);
        continue;
    }
    
    let brkImmediate = extractBrkImmediate(instrU32);
    
    // Only handle brk #0x69 (JIT memory mapping request).
    if (brkImmediate === 0x69) {
        validBreakpoints++;
        
        let jitPageAddress = x0Num;
        // If x1 is 0, use the default size of 64KB (0x10000).
        // Manic EMU's CodeBlock typically requests large memory chunks (tens of MB for CPU JIT)
        // but also asks for smaller ones (like 4KB/16KB for SpinLock and Shader JIT).
        let size = x1Num > 0n ? x1Num : 0x10000n;
        
        log(`[Manic EMU] ----------------------------------------`);
        log(`[Manic EMU] JIT Request #${validBreakpoints}`);
        log(`[Manic EMU]   Address: 0x${jitPageAddress.toString(16)}`);
        log(`[Manic EMU]   Size: 0x${size.toString(16)} (${formatSize(Number(size))})`);
        
        // Call prepare_memory_region to mark the memory as executable.
        let prepareJITPageResponse = prepare_memory_region(Number(jitPageAddress), Number(size));
        log(`[Manic EMU]   prepare_memory_region result: ${prepareJITPageResponse}`);
        
        // Log statistics
        totalMemoryMapped += size;
        mappedRegions.push({
            address: `0x${jitPageAddress.toString(16)}`,
            size: Number(size),
            index: validBreakpoints
        });
        
        log(`[Manic EMU]   Total JIT memory mapped: ${formatSize(Number(totalMemoryMapped))}`);
        
        // Set PC+4 to continue program execution
        let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
        send_command(`P20=${pcPlus4};thread:${tid};`);
        
        log(`[Manic EMU]   Resumed execution at PC=0x${(pcNum + 4n).toString(16)}`);
        log(`[Manic EMU] ----------------------------------------`);
        
    } else if (brkImmediate === 0x70 || brkImmediate === 0x71) {
        // brk #0x70 and brk #0x71 are breakpoints used by some debuggers.
        // Skip directly to PC+4 and continue execution.
        log(`[Manic EMU] Debug breakpoint brk #0x${brkImmediate.toString(16)} at PC=0x${pcNum.toString(16)}, skipping...`);
        let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
        send_command(`P20=${pcPlus4};thread:${tid};`);
        
    } else {
        // Other BRK instructions, skip PC+4 and continue execution.
        log(`[Manic EMU] Unknown brk #0x${brkImmediate.toString(16)} at PC=0x${pcNum.toString(16)}, skipping...`);
        let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
        send_command(`P20=${pcPlus4};thread:${tid};`);
    }
}

// This line of code will never run because it's an infinite loop
// log(`[Manic EMU] Script ended`);
