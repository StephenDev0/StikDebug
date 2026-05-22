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

function attach(breakpointcount) {
    let pid = get_pid();
    log(`pid = ${pid}`);
    let attachResponse = send_command(`vAttach;${pid.toString(16)}`);
    log(`attach_response = ${attachResponse}`);
    
    let validBreakpoints = 0;
    let totalBreakpoints = 0;

    while (validBreakpoints < breakpointcount) {
        totalBreakpoints++;
        log(`Handling breakpoint ${totalBreakpoints} (looking for valid breakpoint ${validBreakpoints + 1}/${breakpointcount})`);
        
        let brkResponse = send_command(`c`);
        log(`brkResponse = ${brkResponse}`);
        
        let tidMatch = /T[0-9a-f]+thread:(?<tid>[0-9a-f]+);/.exec(brkResponse);
        let tid = tidMatch ? tidMatch.groups['tid'] : null;
        let pcMatch = /20:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
        let pc = pcMatch ? pcMatch.groups['reg'] : null;
        let x0Match = /00:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
        let x0 = x0Match ? x0Match.groups['reg'] : null;
        let x1Match = /01:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
        let x1 = x1Match ? x1Match.groups['reg'] : null;
        
        if (!tid || !pc || !x0) {
            log(`Failed to extract registers: tid=${tid}, pc=${pc}, x0=${x0}, x1=${x1}`);
            continue;
        }
        
        const pcNum = littleEndianHexStringToNumber(pc);
        const x0Num = littleEndianHexStringToNumber(x0);
        const x1Num = littleEndianHexStringToNumber(x1);
        log(`tid = ${tid}, pc = ${pcNum.toString(16)}, x0 = ${x0Num.toString(16)}, x1 = ${x1Num.toString(16)}`);
        
        let instructionResponse = send_command(`m${pcNum.toString(16)},4`);
        log(`instruction at pc: ${instructionResponse}`);
        let instrU32 = littleEndianHexToU32(instructionResponse);
        let brkImmediate = extractBrkImmediate(instrU32);
        log(`BRK immediate: 0x${brkImmediate.toString(16)} (${brkImmediate})`);
        
        if (brkImmediate !== 0x69) {
            log(`Skipping breakpoint: brk immediate was not 0x69 (was 0x${brkImmediate.toString(16)})`);
            continue;
        }
        
        log(`BRK immediate matches expected value 0x69 - processing valid breakpoint ${validBreakpoints + 1}/${breakpointcount}`);
        
        let jitPageAddress = x0Num
        log(`Got rx address: 0x${jitPageAddress.toString(16)}`);
        
        let prepareJITPageResponse = prepare_memory_region(jitPageAddress, x1Num);
        log(`prepareJITPageResponse = ${prepareJITPageResponse}`);
        
        let putX0Response = send_command(`P0=${numberToLittleEndianHexString(jitPageAddress)};thread:${tid};`);
        log(`putX0Response = ${putX0Response}`);
        
        let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
        let pcPlus4Response = send_command(`P20=${pcPlus4};thread:${tid};`);
        log(`pcPlus4Response = ${pcPlus4Response}`);
        
        validBreakpoints++;
        log(`Completed valid breakpoint ${validBreakpoints}/${breakpointcount} - returning address 0x${jitPageAddress.toString(16)}`);
    }
    
    let detachResponse = send_command(`D`);
    log(`detachResponse = ${detachResponse}`);
}

attach(3); // MeloNX uses 3 breakpoints, adjust as needed.
