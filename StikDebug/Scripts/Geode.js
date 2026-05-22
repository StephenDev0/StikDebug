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

let pid = get_pid();
log(`pid = ${pid}`);
let attachResponse = send_command(`vAttach;${pid.toString(16)}`);
log(`attach_response = ${attachResponse}`);

let validBreakpoints = 0;
let totalBreakpoints = 0;
let invalidBreakpoints = 0;

while (invalidBreakpoints < 10) {
	totalBreakpoints++;
	log(`Handling breakpoint ${totalBreakpoints} (valid: ${validBreakpoints})`);
	
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
		invalidBreakpoints++;
		continue;
	}

	const pcNum = littleEndianHexStringToNumber(pc);
	const x0Num = littleEndianHexStringToNumber(x0);
	const x1Num = x1 ? littleEndianHexStringToNumber(x1) : 0n;
	log(`tid = ${tid}, pc = ${pcNum.toString(16)}, x0 = ${x0Num.toString(16)}, x1 = ${x1Num.toString(16)}`);
	
	let instructionResponse = send_command(`m${pcNum.toString(16)},4`);
	log(`instruction at pc: ${instructionResponse}`);
	let instrU32 = littleEndianHexToU32(instructionResponse);
	let brkImmediate = extractBrkImmediate(instrU32);
	log(`BRK immediate: 0x${brkImmediate.toString(16)} (${brkImmediate})`);
	
	if (brkImmediate !== 0x69 && brkImmediate !== 0x70 && brkImmediate !== 0x71) {
		log(`Skipping: BRK immediate not 0x69 or 0x70 or 0x71 (was 0x${brkImmediate.toString(16)})`);
		invalidBreakpoints++;
		continue;
	}
	invalidBreakpoints = 0;
	
	if (brkImmediate === 0x69) { // usual jit mapping
		log(`Received command to process JIT mapping (0x69)`);
		
		let jitPageAddress = x0Num;
		let size = x1Num > 0n ? x1Num : 0x10000n; // allocate 64 KB if x1 somehow is 0
		log(`Got RX page address: 0x${jitPageAddress.toString(16)}, preparing region with 0x${size.toString(16)} bytes!`);
		
		let prepareJITPageResponse = prepare_memory_region(Number(jitPageAddress), Number(size)); // Unsure if this is specific to iOS26 but this func doesnt take in a BigInt, resulting in an error unless converted to a number. I'm not sure how other scripts don't have this problem.
		log(`prepareJITPageResponse = ${prepareJITPageResponse}`);
		
		let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
		let pcPlus4Response = send_command(`P20=${pcPlus4};thread:${tid};`);
		log(`pcPlus4Response = ${pcPlus4Response}`);
		validBreakpoints++;
	} else if (brkImmediate === 0x70) { // patching instructs
		log(`Received command to patch instructions (0x70)`);
		
		let x2Match = /02:(?<reg>[0-9a-f]{16});/.exec(brkResponse);
		let x2 = x2Match ? x2Match.groups['reg'] : null;

		if (!x1 || !x2) {
			log(`Missing x1 or x2 for function patching`);
			continue;
		}

		let destAddr = x0Num;
		let srcAddr = x1Num;
		let size = x2 ? littleEndianHexStringToNumber(x2) : 10n;
		log(`Patching: dest=0x${destAddr.toString(16)}, src=0x${srcAddr.toString(16)}, size=0x${size.toString(16)}`);
		
		// Unsure exactly why, but anything over 4 MB freezes the app for some reason, so we will set a soft limit
		if (size > 0x400000n) {
			log(`Size too large (0x${size.toString(16)}), skipping`);
			let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
			let pcPlus4Response = send_command(`P20=${pcPlus4};thread:${tid};`);
			log(`pcPlus4Response = ${pcPlus4Response}`);
			validBreakpoints++;
			continue;
		}
		try {
			// m (read) = `m${curPointer.toString(16)},<size>`
			// M (write) = `M${curPointer.toString(16)},<size>:<your hex instructions goes here>`
			const CHUNK_SIZE = 0x4000n; // 16 KB
			for (let i = 0n; i < size; i += CHUNK_SIZE) {
				let chunkSize = i + CHUNK_SIZE <= size ? CHUNK_SIZE : size - i;
				let readAddr = srcAddr + i;
				let writeAddr = destAddr + i;
				let readRes = send_command(`m${readAddr.toString(16)},${chunkSize.toString(16)}`);
				if (readRes && readRes.length > 0) {
					let writeResponse = send_command(`M${writeAddr.toString(16)},${chunkSize.toString(16)}:${readRes}`);
					if (writeResponse !== "OK") {
						log(`Write failed at offset ${i.toString(16)}`);
						break;
					}
				}
				if (Number(i / CHUNK_SIZE) % 10 === 0) {
					log(`Progress: 0x${i.toString(16)}/0x${size.toString(16)}`);
				}
			}
			log(`Memory write completed!`);
		} catch (e) {
            log(`Memory write failed: ${e}`);
		}
		
		let pcPlus4 = numberToLittleEndianHexString(pcNum + 4n);
		let pcPlus4Response = send_command(`P20=${pcPlus4};thread:${tid};`);
		log(`pcPlus4Response = ${pcPlus4Response}`);
		validBreakpoints++;
	} else if (brkImmediate === 0x71) { // detach, might be unnecessary
		break;
	}
	
	log(`Completed breakpoint ${validBreakpoints}`);
}
log(`Stopping script (Received 0x71 or too many invalid breakpoints)`);
let detachResponse = send_command(`D`);
log(`detachResponse = ${detachResponse}`);
