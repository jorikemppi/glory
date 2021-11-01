--Glory, a 512 byte intro for the TIC-80 by jobe / matt current.
--Released at Inercia Demoparty 2021.
--This should compress into a 512 byte .tic cart file using tic-tool.

--Set up buffer for the temporal blur effect.
buffer = {}

--The next comment sets up a directive for so that tic-tool applies a size optimization technique.

-- transform to load
function TIC()

	--The music data is stored in integers that contain n-bit values. This function gets the subbits.	
	function get_subbits(e, w, k)
		return e >> w * k & 2 ^ k - 1
	end

	t = time() / 200
	
	--Set random seed according to time so that the shapes change in time with music.
	math.randomseed(t/6)
	
	cls(2)
	
	--Generate the palette. Leave 0 alone so it will always be black-ish.
	for i = 1, 47 do
		--Avoid a for loop with a boolean expression. Unless i % 3 == 0 (which means we're generating the red component of the RGB color), v is 0.
		v = i % 3 == 0 and 60 + 195 / ((i + 1) * .99 * math.sin(t)) or 0
		poke(16320 + i, math.min(255, v + 1.13 ^ i))
	end

	--Set the sound registers.
	for i = 0, 2 do
	
		--Set the starting memory address of the channel.
		addr = 65436 + i * 18
		
		--Apply delay to channels 1 and 2.
		tdelay = t + i * 14
		
		--Generate sawtooth value. Use time for amplitude. There's an overflow wraparound at full amplitude,
		--which creates a nice distortion burst at the start of the note.
		for j = 2, 33 do
			poke4(2 * addr + j, 7 - 1.18 ^ (14 - 13 * (tdelay % 1)) * (1 - j % 16 / 2))
		end	

		--Note patterns are stored as semitone deviations from our base tone, which is 117 Hz.
		patterns = {9628018, 9677171, 7391024}
		--The integer 15717 contains the pattern list.
		pattern = patterns[get_subbits(15717, tdelay // 6 % 7, 2)]
		--Calculate the frequency. The ratio between semitones is 2 ^ (1 / 12), 1.059 is close enough.
		freq = 117 * 1.059 ^ get_subbits(pattern, tdelay // 1 % 6, 4) // 1
		
		--Set the frequency and volume to the registers. If the frequency is greater than 255 then the most significant bit needs to go to the
		--next memory address, hence the "freq >> 8".
		poke(addr, freq)
		poke(addr + 1, ((11 // (i + 1) - 1) << 4) + (freq >> 8))
		
		--Generate the squarewave on channel 3. Also generate it again outside the sound register memory area because this way we can fit
		--it into the for loop and use the same pattern data as the sawtooth generator loop, saving space.
		
		--Generate waveform.
		memset(addr + 56, 255, 16)		
		memset(addr + 56, 0, 8)
		
		--Set frequency and volume.
		poke(addr + 55, 128)
		poke(addr + 54, 117 * 1.059 ^ get_subbits(pattern, 0, 4) // 2)

	end	
	
	--This function generates a vertex.	
	function getpt(dist, angl)
		--Multiply the input rotation value by 2 * pi, divide by amount of vertices, and add t / 19 for rotation. 
		angl = angl * 2 * math.pi / verts + t / 19
		--Rotate (dist, 0) by angl, translate by half the screen resolution, and return.
		return 120 + dist * math.cos(angl), 68 + dist * math.sin(angl)
	end

	--Draw the geometry.
	verts = math.random(3, 31)

	for j = 1, 7 do
		
		depth = math.random(0, 240)
	
		for i = .5 * j, verts + .5 * j do
			x1, y1 = getpt(165, i)
			x2, y2 = getpt(165, i + 1)
			x3, y3 = getpt(depth, i + .5)
			x4, y4 = getpt(depth, i + .5 + j)
			tri(x1, y1, x2, y2, x3, y3, 1.07 ^ j)
			line(x3, y3, x4, y4, 1.47 ^ j)
		end
	
	end
	
	--Apply the temporal blur into VRAM. We will start from 1 and ignore the top left pixel because whoever designed Lua decided that
	--table indices should start at 1.
	for i = 1, 32639 do
		--The buffer will be nil on the first frame, so we need to initialize the values.
		v = buffer[i] or 0
		--Read pixel value from VRAM. Don't actually read the same pixel, but a nearby pixel, to create some glitchiness.
		--Add that value to what's in the buffer and multiply by .8.
		buffer[i] = .8 * v + peek4(i) * ((i + t) % (1 + math.sin(t)))
		--Write the buffer value into VRAM. Make sure it doesn't wrap around if the value is greater than 15.
		poke4(i, math.min(15, buffer[i]))
	end
	
end