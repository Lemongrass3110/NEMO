function IncreaseAtkDisplay() {
	
	//Step 1 - Find the location where 999999 is checked
	var code = " 3F 42 0F 00 7E AB B9 3F 42 0F 00";
	var refoffset = exe.findCode(code, PTYPE_HEX, true, "\xAB");
	if (refoffset == -1) {
		return "Failed in Step 1";
	}	
	//Step 2 - Get the first instruction 
	code = " 6A FF 68 AB AB AB 00 64 A1 00 00 00 00 50 83 EC";
	var first = exe.find(code, PTYPE_HEX, true, "\xAB", refoffset - 100, refoffset);
	if (first == -1) {
		return "Failed in Step 2";
	}
	
	//Step 3 - Update the stack (decrease 16 more)
	offsetStack(first+16, 1);
	
	//Change JLE to JMP
	exe.replace(refoffset + 4, "EB", PTYPE_HEX);		
		
	//Next set of steps vary based on the compiler version
	if (exe.getClientDate() > 20130605) {
		//Change 34 to 44 in MOV DWORD PTR SS:[EBP-34], EDI
		offsetStack(refoffset-3);
		
		//First get the relevant locations for replace and extractions
		var digcalc = exe.find(" C7 45 AB 01 00 00 00", PTYPE_HEX, true, "\xAB", refoffset+4);
		var divider = exe.find(" B8 67 66 66 66 F7 E9", PTYPE_HEX, false, " ", digcalc+7);
		var ebpcalc = exe.find(" B8 67 66 66 66 F7 E9", PTYPE_HEX, false, " ", divider+7);			
		var ecxpush = exe.find(" B9", PTYPE_HEX, false, " ", ebpcalc+7);
		var jmpto   = exe.find(" E8", PTYPE_HEX, false, " ", ecxpush+5);
		
		//Num Digit calculator			
		var obyte = (exe.fetchByte(digcalc+2)-16).packToHex(1);
		var code =  
				  ' C7 45' + obyte + ' 01 00 00 00'	//MOV DWORD PTR SS:[EBP-x], 1
				+ ' B8 09 00 00 00'					//MOV EAX, 9
				+ ' 39 C1'							//CMP ECX, EAX
				+ ' 7E 0E'							//JLE SHORT skip
				+ ' 8D 04 80'						//LEA EAX, [EAX*4 + EAX]
				+ ' 01 C0'							//ADD EAX, EAX
				+ ' 83 C0 09'						//ADD EAX, 9
				+ ' 83 45' + obyte + ' 01'				//ADD DWORD PTR SS:[EBP-x], 1
				+ ' EB EE'							//JMP loop
				+ ' EB'+ ((divider-7) - (digcalc+32)).packToHex(1); //JMP to divider.
				;
				
		exe.replace(digcalc, code, PTYPE_HEX);
		
		//Digit Splitter - prefix
		obyte = (exe.fetchByte(ebpcalc-3) - 16).packToHex(4);
		code = " BB" + obyte + " 31 F6";
		exe.replace(divider-7, code, PTYPE_HEX);
		
		//Digit Splitter - suffix
		obyte = exe.fetchHex(ecxpush, 5);
		code =    ' 89 EA'			//MOV EDX,EBP
		        + ' 8D 2C 2B'     //LEA EBP,[EBP+EBX]
		        + ' 83 C3 04'     //ADD EBX,4
		        + ' 89 4D 00'     //MOV DWORD PTR SS:[EBP],ECX
		        + ' 89 D5'         //MOV EBP,EDX
				+ ' 89 C1'			//MOV ECX, EAX
		        + ' 46'             //INC ESI
		        + ' 83 FE 09'     //CMP ESI,09
		        + ' 7C' + (0-(ebpcalc-5+21 - divider)).packToHex(1) //JL SHORT loop
				+ ' 90'				//NOP
				+ ' 89 EA'			//MOV EDX,EBP
				+ ' 8D 2C 2B'		//LEA EBP,[EBP+EBX]
				+ ' 89 4D 00'		//MOV DWORD PTR SS:[EBP],ECX
				+ ' 89 D5'			//MOV EBP,EDX
				+ obyte
				+ ' EB' + (jmpto - (ebpcalc-5+39)).packToHex(1)//JMP SHORT to next loc
				;
				
		exe.replace(ebpcalc-5, code, PTYPE_HEX);
		
		//Change 3C to 4C in MOV DWORD PTR SS:[EBP-3C], EAX
		var offset = exe.find(" 89 AB AB 75", PTYPE_HEX, true, "\xAB", jmpto);
		offsetStack(offset + 2);
		
		//Change 2C to 3C in MOV EAX, DWORD PTR SS:[EBP-2C]
		offset = exe.find(" 8B AB AB 33", PTYPE_HEX, true, "\xAB", offset+5);
		offsetStack(offset + 2);
		
		//Change 30 to 40 in MOV DWORD PTR SS:[EBP-30], EAX
		offset = exe.find(" 89 AB AB 68", PTYPE_HEX, true, "\xAB", offset+5);
		offsetStack(offset + 2);
		
		//Change 38 to 48 in MOV DWORD PTR SS:[EBP-38], EAX
		offset = exe.find(" 89 AB AB 33", PTYPE_HEX, true, "\xAB", offset+5);
		offsetStack(offset + 2);
		
		//Change 34 to 44 in MOV ECX, DWORD PTR SS:[EBP-34]
		offset = exe.find(" 8B AB AB 8B AB 8B", PTYPE_HEX, true, "\xAB", offset+8);
		offsetStack(offset + 2);
		
		//Change 38 to 48 in MOV DWORD PTR SS:[EBP-38], ESI
		//Change 30 to 40 and 28 to 38 in the next set
		offset = exe.find(" 89 AB AB FF",  PTYPE_HEX, true, "\xAB", offset+8);
		offsetStack(offset + 2);
		offsetStack(offset + 7);
		offsetStack(offset + 11);
		
		//Change 34 to 44 in MOV EAX, DWORD PTR SS:[EBP-34]
		offset = exe.find(" 8B AB AB AB 83", PTYPE_HEX, true, "\xAB", offset+12);
		offsetStack(offset + 2);
		
		//Change 34 to 44 in MOV ECX, DWORD PTR SS:[EBP-34]
		offset = exe.find(" 8B AB AB 8B", PTYPE_HEX, true, "\xAB", offset+7);
		offsetStack(offset + 2);
		
		//Change 3C to 4C in MOV ECX, DWORD PTR SS:[EBP-3C]
		offset = exe.find(" 8B AB AB AB E8", PTYPE_HEX, true, "\xAB", offset+5);
		offsetStack(offset + 2);
		
		//Change 38 to 48 in LEA EAX, [EBP-38]
		offset = exe.find(" 8B AB AB AB 00 00 8B AB AB 8D", PTYPE_HEX, true, "\xAB", offset+9);
		offsetStack(offset + 11);
		
		//Change 30 to 40 in SUB DWORD PTR SS:[EBP-30],8
		offset = exe.find(" 83 AB AB 08 AB 89", PTYPE_HEX, true, "\xAB", offset+12);
		offsetStack(offset + 2);
		
		//Change 2C to 3C in CMP EBX, DWORD PTR SS:[EBP-2C]
		offset = exe.find(" 3B AB AB 0F 8C", PTYPE_HEX, true, "\xAB", offset+8);
		offsetStack(offset + 2);
	}
	else {
		//Change 3C to 4C in LEA EAX, [ESP+3C]
		var offset = exe.find(' 8D AB 24', PTYPE_HEX, true, "\xAB", first+16);
		offsetStack(offset + 3,1);
		
		//Change 50 to 60 in MOV ECX, DWORD PTR SS:[ESP+50]
		offset = exe.find(' 8B AB 24', PTYPE_HEX, true, "\xAB", offset+4);
		offsetStack(offset + 3,1);
		
		//First get the relevant locations for replace and extractions
		var digcalc = exe.find(' C7 44 24 AB 01 00 00 00', PTYPE_HEX, true, "\xAB", refoffset + 4);			
		var divider = exe.find(' B8 67 66 66 66 F7 E9', PTYPE_HEX, false, " ",digcalc+8);
		var espcalc = exe.find(' B8 67 66 66 66 F7 E9', PTYPE_HEX, false, " ", divider+7);
		var ecxpush = exe.find(' B9', PTYPE_HEX, false, " ", espcalc+7);
		var jmpto   = exe.find(' E8', PTYPE_HEX, false, " ", ecxpush+5);
		
		//Num Digit calculator			
		var obyte = (exe.fetchByte(digcalc+3)+16).packToHex(1);
		var code = 
				  ' C7 44 24' + obyte + ' 01 00 00 00'	//MOV DWORD PTR SS:[ESP+x], 1
				+ ' B8 09 00 00 00'				//MOV EAX, 9
				+ ' 39 C1'						//CMP ECX, EAX
				+ ' 7E 0F'						//JLE SHORT skip
				+ ' 8D 04 80'					//LEA EAX, [EAX*4 + EAX]
				+ ' 01 C0'						//ADD EAX, EAX
				+ ' 83 C0 09'					//ADD EAX, 9
				+ ' 83 44 24' + obyte + ' 01'	//ADD DWORD PTR SS:[ESP+x], 1
				+ ' EB ED'						//JMP loop
				+ ' EB' + ((divider-8) - (digcalc+34)).packToHex(1);	//JMP to divider.
				;
				
		exe.replace(digcalc, code, PTYPE_HEX);
		
		//Digit Splitter - prefix
		obyte = exe.fetchByte(espcalc-3).packToHex(4);
		code = " BB" + obyte + " 31 F6 90";
		exe.replace(divider-8, code, PTYPE_HEX);
		
		//Digit Splitter - suffix
		obyte = exe.fetchHex(ecxpush,5);
		code =	  ' 89 E2'		//MOV EDX,ESP
		        + ' 8D 24 1C'	//LEA ESP,[ESP+EBX]
		        + ' 83 C3 04'	//ADD EBX,4
		        + ' 89 0C E4'	//MOV DWORD PTR SS:[ESP],ECX
		        + ' 89 D4'		//MOV ESP,EDX
				+ ' 89 C1'		//MOV ECX, EAX
		        + ' 46'			//INC ESI
		        + ' 83 FE 09'	//CMP ESI,09
		        + ' 7C' + (0-(espcalc-6+21 - divider)).packToHex(1)	//JL SHORT loop
				+ ' 90'			//NOP
				+ ' 89 E2'		//MOV EDX,ESP
				+ ' 8D 24 1C'	//LEA ESP,[ESP+EBX]
				+ ' 89 4D 00'	//MOV DWORD PTR SS:[ESP],ECX
				+ ' 89 D4'		//MOV ESP,EDX
				+ obyte
				+ ' EB' + (jmpto - (espcalc-6+39)).packToHex(1)			//JMP SHORT to next loc
				;
				
		exe.replace(espcalc-6, code, PTYPE_HEX);
		
		//change 58 to 68 in MOV EDI, DWORD PTR SS:[ESP+58]
		offset = exe.find(" 8B AB 24", PTYPE_HEX, true, "\xAB", jmpto+1);
		offsetStack(offset + 3,1);
		
		//change 50 to 60 in MOV EAX, DWORD PTR SS:[ESP+50]
		offset = exe.find(" 8B AB 24", PTYPE_HEX, true, "\xAB", offset+4);
		offsetStack(offset + 3,1);
		
		//Change 58 to 68 in MOV EDI, DWORD PTR SS:[ESP+58]
		offset = exe.find(" 8B AB 24 AB 68", PTYPE_HEX, true, "\xAB", offset+4);
		offsetStack(offset + 3,1);
		
		//Change 44 to 54 in MOV DWORD PTR SS:[ESP+44], ESI
		offset = exe.find(" 89 AB 24 AB 3B", PTYPE_HEX, true, "\xAB", offset+4);
		offsetStack(offset + 3,1);
		
		//Change 44 to 54 in MOV DWORD PTR SS:[ESP+44],-1
		//Change 54 to 64 in MOV ECX, DWORD PTR SS:[ESP+54]
		offset = exe.find(" C7 AB 24", PTYPE_HEX, true, "\xAB", offset+4);
		offsetStack(offset + 3,1);
		offsetStack(offset + 11,1);
		
		//Change 38 to 48 in MOV DWORD PTR SS:[ESP+38], ESI
		offset = exe.find(" 89 AB 24", PTYPE_HEX, true, "\xAB", offset+12);
		offsetStack(offset + 3,1);
		
		//Change 50 to 60 in CMP EBX, DWORD PTR SS:[ESP+50]
		offset = exe.find(" 3B AB 24 AB 89", PTYPE_HEX, true, "\xAB", offset+4);
		offsetStack(offset + 3,1);
		
		//Change 3C to 4C in MOV ECX, DWORD PTR SS:[ESP+3C]
		offset = exe.find(" 8B AB 24", PTYPE_HEX, true, "\xAB", offset+6);
		offsetStack(offset + 3,1);
		
		//Change 34 to 44 in ADD ESP, 44
		offset = exe.find(" 83 C4", PTYPE_HEX, true, "\xAB", offset+4);
		offsetStack(offset + 2);		
	}
	return true;
}

function offsetStack(loc, sign) {
	if (typeof(sign) === 'undefined') sign = -1;
	var obyte = exe.fetchByte(loc) + sign * 16;
	exe.replace(loc, obyte.packToHex(1), PTYPE_HEX);
}
