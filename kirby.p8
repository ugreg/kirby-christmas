pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- kirby mod of 
-- jelpi demo by zep

greguniverse = {}

#include colors.lua
#include sfx.lua

level=1

num_players = 1
corrupt_mode = false
paint_mode = false
max_actors = 64
play_music = false

function make_actor(k,x,y,d)
	local a = {
		k=k,
		frame=0,
		frames=4,
		life = 1,
		hit_t=0,
		x=x, y=y, 
		dx=0, dy=0,
		homex=x,homey=y,
		ddx = 0.02, -- acceleration
		ddy = 0.06, -- gravity
		w=3/8,h=0.5, -- half-width
		d=d or -1, -- direction
		bounce=0.8,
		friction=0.87,
		can_bump=true,
		dash=0,
		super=0,
		t=0,
		flying = false,
		standing = false,
		draw=draw_actor,
		move=move_actor,
	}
	
	-- attributes by flag	
	if (fget(k,6)) then
		a.is_pickup=true
	end
	
	if (fget(k,7)) then
		a.is_monster=true
		a.move=move_monster
	end
	
	if (fget(k,4)) then
		a.ddy = 0 -- zero gravity
	end
	
	-- attributes from actor_dat	
	for k,v in pairs(actor_dat[k])
	do
		a[k]=v
	end
	
	if (#actor < max_actors) then
		add(actor, a)
	end
	
	return a
end

function make_sparkle(k,x,y,col)
	local s = {
		x=x,y=y,k=k,
		frames=1,
		col=col,
		t=0, max_t = 8+rnd(4),
		dx = 0, dy = 0,
		ddy = 0
	}
	if (#sparkle < 512) then
		add(sparkle,s)
	end
	return s
end

function make_player(k, x, y, d)

	local a = make_actor(k, x, y, d)
	
	a.id = 0 -- player 1
	a.bounce = 0
	a.ddy = 0.064
	a.delay = 0
	a.flying = false
	a.frames = 8
	a.inhale = false
	a.is_player=true
	a.life = 6
	a.move=move_player
	a.score = 0
		
	return a
end

function _init()

	init_actor_data() 
	init_level(level)
	menuitem(1,
	"restart level",
	function()
		init_level(level)
	end)	
		
end

-- clear_cel using neighbour val
-- prefer empty, then non-ground
-- then left neighbour
function clear_cel(x, y)
	local val0 = mget(x-1,y)
	local val1 = mget(x+1,y)
	if ((x>0 and val0 == 0) or 
					(x<127 and val1 == 0)) then
		mset(x,y,0)
	elseif (not fget(val1,1)) then
		mset(x,y,val1)
	elseif (not fget(val0,1)) then
		mset(x,y,val0)
	else
		mset(x,y,0)
	end
end


function move_spawns(x0, y0)

	x0=flr(x0)
	y0=flr(y0)
	
	-- spawn actors close to x0,y0
	for y=0,16 do
		for x=x0-10,max(16,x0+14) do
			local val = mget(x,y)
			
			-- actor
			if (fget(val, 5)) then    
				m = make_actor(val,x+0.5,y+1)
				clear_cel(x,y)
			end			
		end
	end
end

function solid(x, y, ignore)

	if (x < 0 or x >= 128 ) then
		return true end
	
	local val = mget(x, y)
	
	-- flag 6: can jump up through
	-- (and only top half counts)	
	if (fget(val,6)) then
		if (ignore) return false
		-- bottom half: solid iff solid below
		if (y%1 > 0.5) return solid(x,y+1)
	end
	
	return fget(val, 1)
end

-- solidx: solid at 2 points
-- along x axis
local function solidx(x,y,w)
	return solid(x-w,y) or
		solid(x+w,y)
end


function move_player(pl)

	move_actor(pl)
	
	if (pl.y > 18) pl.life=0

	local b = pl.id

	if (pl.life <= 0) then				
		for i=1,32 do
			s=make_sparkle(69,
				pl.x, pl.y-0.6)
			s.dx = cos(i/32)/2
			s.dy = sin(i/32)/2
			s.max_t = 30 
			s.ddy = 0.01
			s.frame=69+rnd(3)
			s.col = 7
		end
		
		-- sfx(greguniverse.sfx.player_death)
		pl.death_t=time()
				
		return
	end
	
	local accel = 0.05
	local q=0.7
	
	if pl.super > 0 then 
		q*=1.5
		accel*=1.5
	end
	
	if not pl.standing then
		accel = accel / 2
	end
		
	-- player control
	if (btn(0,b)) then 
		pl.dx = pl.dx - accel; pl.d=-1 end
	if (btn(1,b)) then 
		pl.dx = pl.dx + accel; pl.d=1 end
	
	-- float
	if pl.flying then
		pl.ddy = 0.006
	else
		pl.ddy = 0.06
	end

	-- jump and fly
	if (btnp(4,b) and pl.dy < 1 and not pl.inhale) then
		if not pl.standing then
			pl.dy = -0.08
			pl.ddy = 0
			pl.flying = true
		else			
			pl.dy = -0.62
		end
		-- sfx(greguniverse.sfx.jump)
	end	

	-- inhale
	if (btn(5,b)) then
		-- sfx(greguniverse.sfx.inhale)
		pl.inhale = true
		for i=1,3 do
			local sx = pl.x + pl.d*(2.2055*i/3)
			if (pl.d == -1) sx  = sx - 0.2
			local s = make_sparkle(
				85, 
				sx,
				pl.y - 0.5)
			
			if (rnd(2) < 1) then
				s.col = 7
			end
			s.dx = pl.dx*2
			s.dy = -0.05*i/2
			s.x = s.x + 0.3
			s.y = s.y + 0.3
		end
		pl.dx = 0
	else
		pl.inhale = false
	end

	if (pl.inhale or btn(3,b)) then 
		pl.flying = false
	end
	
	-- super: give more dash	
	if (pl.super > 0) pl.dash=2
	
	pl.delay = max(0,pl.delay-1)
	pl.super = max(0, pl.super-1)
	
	-- frames
	-- walk
	if pl.standing then
		pl.flying = false
		local f = (pl.frame+abs(pl.dx)*2) % pl.frames	
		if f < 4 then
			pl.frame = f
		elseif f > 4 then
			pl.frame = 0
		end
	else
		pl.frame = (pl.frame+abs(pl.dx)/2) % pl.frames
	end

	-- fly
	if not pl.standing then
		local f = (pl.frame) % pl.frames	
		if f > 5 then
			pl.frame = f
		elseif f < 8 then
			pl.frame = 6
		end
	else
		pl.frame = (pl.frame+abs(pl.dx)/2) % pl.frames
	end

	if pl.inhale then 
		pl.frame = 4			
	end
	
	if (abs(pl.dx) < 0.1 and not pl.inhale and not pl.flying) pl.frame = 0
	
end

function move_monster(m)
	
	move_actor(m)
	
	if (m.life<=0) then
		bang_puff(m.x,m.y-0.5,104)

		-- sfx(greguniverse.sfx.enemy_death)
		return
	end
	

	m.dx = m.dx + m.d * m.ddx

	m.frame = (m.frame+abs(m.dx)*3+4) % m.frames
	
	-- jump
	if (false and m.standing and rnd(10) < 1)
	then
		m.dy = -0.5
	end
	
	-- hit cooldown
	-- (can't get hit twice within
	--  half a second)
	if (m.hit_t>0) m.hit_t-=4

end


function smash(x,y,b)

		local val = mget(x, y, 0)
		if (not fget(val,4)) then
			-- not smashable
			-- -> pass on to solid()
			return solid(x,y,b)
		end    
		
		
		-- spawn
		if (val == 48) then
			local a=make_actor(
				loot[#loot],
				x+0.5,y-0.2)
			
			a.dy=-0.8
			a.d=flr(rnd(2))*2-1
			a.d=0.25 -- swirly
			loot[#loot]=nil
		end
		
				
		clear_cel(x,y)
		sfx(10)
			
		-- make debris
		
		for by=0,1 do
			for bx=0,1 do
				s=make_sparkle(22,
				0.25+flr(x) + bx*0.5, 
				0.25+flr(y) + by*0.5,
				0)
				s.dx = (bx-0.5)/4
				s.dy = (by-0.5)/4
				s.max_t = 30 
				s.ddy = 0.02
			end
		end

		return false -- not solid
end

function move_actor(a)

	if (a.life<=0) del(actor,a)
	
	a.standing=false
	
	-- when dashing, call smash()
	-- for any touched blocks
	-- (except for landing blocks)
	local ssolid=
		a.inhale == true and smash or solid 
	
	-- solid going down -- only
	-- smash when holding down
	local ssolidd=
		a.dash>0 and (btn(3,a.id))
		 and smash or solid 
		
	--ignore jump-up-through
	--blocks only when have gravity
	local ign=a.ddy > 0
	
	-- x movement 
	
	-- candidate position
	x1 = a.x + a.dx + sgn(a.dx)/4
	
	if not ssolid(x1,a.y-0.5,ign) then
		-- nothing in the way->move
		a.x += a.dx 		
	else -- hit wall	
		-- bounce
		-- if (a.dash > 0)sfx(greguniverse.sfx.bounce) 
		a.dx *= -1		
		a.hit_wall=true		
		-- monsters turn around
		if (a.is_monster) then
			a.d *= -1
			a.dx = 0
		end		
	end
	
	-- y movement	
	local fw=0.25

	if (a.dy < 0) then
		-- going up
		
		if (
		 ssolid(a.x-fw, a.y+a.dy-1,ign) or
		 ssolid(a.x+fw, a.y+a.dy-1,ign))
		then
			a.dy=0
			
			-- snap to roof
			a.y=flr(a.y+.5)
			
		else
			a.y += a.dy
		end

	else
		-- going down	
		local y1=a.y+a.dy
		if ssolidd(a.x-fw,y1) or
		   ssolidd(a.x+fw,y1)
		then
		
			-- bounce
			if (a.bounce > 0 and 
			    a.dy > 0.2) 
			then
				a.dy = a.dy * - a.bounce
			else
			
			a.standing=true
			a.dy=0
			end
			
			-- snap to top of ground
			a.y=flr(a.y+0.75)	
			
		else
			a.y += a.dy  
		end
		-- pop up		
		while solid(a.x,a.y-0.05) do
			a.y -= 0.125
		end

	end


	-- gravity and friction
	a.dy += a.ddy
	a.dy *= 0.95

	-- x friction
	a.dx *= a.friction
	if (a.standing) then
		a.dx *= a.friction
	end

--end
	
	-- counters
	a.t = a.t + 1
end


function monster_hit(m)
	if(m.hit_t>0) return
	
	m.life-=1
	m.hit_t=15
	m.dx/=4
	m.dy/=4
	-- survived: thunk sound
	-- if (m.life>0) sfx(greguniverse.sfx.actor_hit)
	
end

function player_hit(p,a)
	p.life-=1
	p.dx *= -2
	p.dy *= -4
	a.dx *= -10
	-- sfx(greguniverse.sfx.actor_hit)
	for i=1,3 do
		local s = make_sparkle(
			69+rnd(3),
			p.x+p.dx*i/3, 
			p.y+p.dy*i/3 - 0.3,
			(p.t*3+i)%9+7)
		if (rnd(2) < 1) then
			s.col = 7
		end
		s.dx = -p.dx*0.1
		s.dy = -0.05*i/4
		s.x = s.x + rnd(0.6)-0.3
		s.y = s.y + rnd(0.6)-0.3
	end
end

function collide_event(a1, a2)

	if (a1.is_monster and
		a1.can_bump and
		a2.is_monster) then
		local d=sgn(a1.x-a2.x)
		if (a1.d!=d) then
			a1.dx=0
			a1.d=d
		end
	end
	
	-- bouncy mushroom
	if (a2.k==82) then
		if (a1.dy > 0 and 
		not a1.standing) then
			a1.dy=-1.1
			a2.active_t=6
			-- sfx(greguniverse.sfx.inhale)
		end
	end

	if(a1.is_player) then
		if(a2.is_pickup) then

			if (a2.k==64) then
				a1.super = 30*4
				--sfx(17)
				a1.dx = a1.dx * 2
				--a1.dy = a1.dy-0.1
				-- a1.standing = false
				-- sfx(greguniverse.sfx.get_lollipop)
			end

			-- watermelon
			if (a2.k==80) then
				a1.score+=5
				-- sfx(greguniverse.sfx.get_pickup)
			end
			
			-- end level
			if (a2.k==65) then
				finished_t=1
				bang_puff(a2.x,a2.y-0.5,108)
				del(actor,pl[1])
				del(actor,pl[2])
				music(-1,500)
				-- sfx(greguniverse.sfx.level_clear)
			end
			
			-- glitch mushroom
			if (a2.k==84) then
				glitch_mushroom = true
				sfx(29)
			end
			
			-- gem
			if (a2.k==67) then
				a1.score = a1.score + 1				
				-- total gems between players
				gems+=1				
			end
			
			-- bridge builder
			if (a2.k==99) then
				local x,y=flr(a2.x)+.5,flr(a2.y+0.5)
				for xx=-1,1 do
				if (mget(x+xx,y)==0) then
					local a=make_actor(53,x+xx,y+1)
					a.dx=xx/2
				end
				end
			end
			
			a2.life=0
			
			s=make_sparkle(85,a2.x,a2.y-.5)
			s.frames=3
			s.max_t=15
			-- sfx(greguniverse.sfx.get_pickup)
		end
		
		if(a2.is_monster) then			
			if(a2.can_bump and a1.inhale) then				
				-- slow down player
				a1.dx *= 0.7
				a1.dy *= -0.7				
				if (btn(🅾️,a1.id))a1.dy -= .5				
				monster_hit(a2)				
			else
				player_hit(a1, a2)				
			end
		end
			
	end
end

function move_sparkle(sp)
	if (sp.t > sp.max_t) then
		del(sparkle,sp)
	end
	
	sp.x = sp.x + sp.dx
	sp.y = sp.y + sp.dy
	sp.dy= sp.dy+ sp.ddy
	sp.t = sp.t + 1
end

-- with inhale!
function collide(a1, a2)
	if (not a1) return
	if (not a2) return	
	if (a1==a2) then return end	
	local dx = a1.x - a2.x
	local dy = a1.y - a2.y
	if (abs(dx) < a1.w+a2.w) then
		if (abs(dy) < a1.h+a2.h) then
			collide_event(a1, a2)
			collide_event(a2, a1)
		end
	end
	if a1.is_player and a1.inhale then
		if (abs(dx) < a1.w+a2.w+2) then
			if (abs(dy) < a1.h+a2.h) then
				collide_event(a1, a2)
			end
		end
	end
end

function collisions()
	-- to do: optimize if too
	-- many actors
	for i=1,#actor do
		for j=i+1,#actor do
			collide(actor[i],actor[j])
		end
	end	
end


function outgame_logic()

	if death_t==0 and
			not alive(pl[1]) and 
			not alive(pl[2]) then
			death_t=1
			music(-1)
			-- sfx(greguniverse.sfx.game_over)
			
	end

	if (finished_t > 0) then
	
		finished_t += 1
		
		if (finished_t > 60) then
			if (btnp(❎)) then
				fade_out()
				init_level(level+1)
			end
		end
	
	end

	if (death_t > 0) then
		death_t = death_t + 1
		if (death_t > 45 and 
			btn()>0)
		then 
				music(-1)
				sfx(-1)
				-- sfx(greguniverse.sfx.fade_out)
				fade_out()				
				
				-- restart cart end of slice
				init_level(level)
			end
	end
	
end

function _update() 
	
	for a in all(actor) do
		a:move()
	end
		
	foreach(sparkle, move_sparkle)
	collisions()
	
	for i=1,#pl do
		move_spawns(pl[i].x,0)
	end
	
	outgame_logic()
	update_camera()

	if (glitch_mushroom or corrupt_mode) then
		for i=1,4 do
			poke(rnd(0x8000),rnd(0x100))
		end
	end
	
	level_t += 1
end

function _draw()

	cls(12)
	
	-- view width
	local vw=split and 64 or 128

	cls()
	
	-- decide which side to draw
	-- player 1 view
	local view0_x = 0
	if (split and pl[1].x>pl[2].x)
	then view0_x = 64 end
	
	-- player 1 (or whole screen)
	draw_world(
		view0_x,0,vw,128,
		cam_x,cam_y)
	
	-- player 2 view if needed
	if (split) then
		cam_x = pl_camx(pl[2].x,64)
		draw_world(64-view0_x,0,vw,128,
			cam_x, cam_y)
	end
	
	camera()pal()clip()
	if (split) line(64,0,64,128,0)

	-- player score
	camera(0,0)
	color(7)

	draw_merrrryyyyy_christmas()

	if (death_t > 45) then
		print("❎ restart",
			44,18+1,14)
		print("❎ restart",
			44,18,7)
	end

	if (finished_t > 0) then
		draw_finished(finished_t)		
	end	
	
	if (paint_mode) apply_paint()

	draw_sign()

	draw_hud()

	debug()
end

function debug()
	-- rectfill(1,1,126,38,0)	
	local pldata=[[debug 
		dx ]]..pl[1].dx..[[ 
		dy ]]..pl[1].dy..[[ 
		x ]]..pl[1].x..[[ 
		y ]]..pl[1].y..[[ 
		inhale ]]..tostr(pl[1].inhale)..[[ 
		standing.. ]]..tostr(pl[1].standing)

	print(pldata,4,20,greguniverse.colors.black)
end

snow = {}
index = 1
for y=1,35 do
	for x=0,32 do
		add(snow, {x=10*x, y=y*5, r=0.1}, index)		
		index+=1
	end
end
snowy = 0.1
function draw_snow()
	for k,v in pairs(snow) do
		circfill(v.x, v.y, v.r, greguniverse.colors.white)
		v.y+=snowy
		if v.y > 130 then
			v.y=5
			r=rnd(2)
		end
	end		
end

function draw_merrrryyyyy_christmas()
	rectfill(1,1,126,16,0)
	rect(1,1,126,16,7)
	for color = 11,7,-1 do			
		local spr_row = 127
		for i=1,14 do			
			t1 = time()*30 + i - color*2
			x = i*8 + cos(t1/40)*3
			y = 4 + (color-7) + cos(t1/50)
			pal(7,color)
			spr(spr_row + i, x, y)
			if (i == 7) spr_row = 136
		end
	end
end

sign_str={
	"",
	[[
		this is an empty level!
		use the map editor to add
		some blocks and monsters.
		in the code editor you
		can also set level=2
	]],
	"",
	[[
		this is not a level!
		
		the bottom row of the map 
		in this cartridge is used
		for making backgrounds.
	]]
}
function draw_sign()
	if (mget(pl[1].x,pl[1].y-0.5)!=25) return

	rectfill(8,6,120,46,0)
	rect(8,6,120,46,7)

	print(sign_str[level],12,12,6)
end

function draw_hud()
	rectfill(0,120,127,127,greguniverse.colors.black)
	for i=0,5 do
		local distance = (i*6)
		circfill(20+distance, 124, 2, greguniverse.colors.dark_green)
	end	
	
	line(118, 121, 119, 120, greguniverse.colors.green)
	line(118, 123, 119, 122)
	line(118, 125, 119, 124)
	line(118, 127, 119, 126)
	line(0, 120, 127, 120, greguniverse.colors.black)
end

function fade_out()
	dpal={0,1,1, 2,1,13,6,
		4,4,9,3, 13,1,13,14}
	
					
	-- palette fade
	for i=0,40 do
		for j=1,15 do
			col = j
			for k=1,((i+(j%5))/4) do
				col=dpal[col]
			end
			pal(j,col,1)
		end
		flip()
	end	
end
-->8
-- draw world

function draw_sparkle(s)

	--spinning
	if (s.k == 0) then
		local sx=s.x*8
		local sy=s.y*8
		
		line(sx,sy,
				sx+cos(s.t*s.spin)*1.4,
				sy+sin(s.t*s.spin)*1.4,
				s.col)
				
		return
	end
	
	if (s.col and s.col > 0) then
		for i=1,15 do
			pal(i,s.col)
		end
	end

	local fr=s.frames * s.t/s.max_t
	fr=s.k+mid(0,fr,s.frames-1)
	spr(fr, s.x*8-4, s.y*8-4)

	pal()
end

function draw_actor(a)

	local fr=a.k + a.frame
	
	local sx=a.x*8-4
	local sy=a.y*8-8
	
	-- sprite flag 3 (green):
	-- draw one pixel up
	if (fget(fr,3)) sy-=1

	-- draw the sprite
	spr(fr, sx,sy,1,1,a.d<0)

	-- sprite flag 2 (yellow):
	-- repeat top line
	-- (for mimo's ears!)	
	if (fget(fr,2)) then
		pal(14,7)
		spr(fr,sx,sy-1,1,1/8,
						a.d<0)
	end	
end

function draw_tail(a)

	draw_actor(a)
	
	local sx=a.x*8
	local sy=a.y*8-2
	local d=-a.d
	sx += d*3
	if (a.d>0) sx-=1
	
	for i=0,4,2 do
		pset(sx+i*d*1,
		  sy + cos(i/16-time())*
		  (1+i)*abs(a.dx)*4,7)
	end
	
end


function apply_paint()
	if (tt==nil) tt=0
	tt=tt+0.25
	srand(flr(tt))
	local nn=rnd(128)
	local xx=0
	local yy=band(nn,127)
	for i=1,1000*13,13 do
		nn+=i
		nn*=33
		xx=band(nn,127)
		local col=pget(xx,yy)
		rectfill(xx,yy,xx+1,yy+1,col)
		line(xx-1,yy-1,xx+2,yy+2,col)
		nn+=i
		nn*=57
		yy=band(nn,127)
		rectfill(xx-1,yy-1,xx,yy,pget(xx,yy))
			
	end
end

-- draw the world at sx,sy
-- with a view size: vw,vh
function draw_world(
		sx,sy,vw,vh,cam_x,cam_y)	
	
	-- reduce jitter
	cam_x=flr(cam_x) 
	cam_y=flr(cam_y)
	
	if (level>=4) cam_y = 0
	
	clip(sx,sy,vw,vh)
	cam_x -= sx
	
	local ldat=theme_dat[level]
	if (not ldat) ldat={}
	
	-- sky
	camera (cam_x/4, cam_y/4)
	
	-- sample palette colour
	local colx=120+level
	
	-- sky gradient
	if (ldat.sky) then
		for y=cam_y,127 do
			col=ldat.sky[
				flr(mid(1,#ldat.sky,
					(y+(y%4)*6) / 16))]
				
			line(0,y,511,y, greguniverse.colors.lavender)
		end
	end

	-- reduce jitter
	cam_x=flr(cam_x) 
	cam_y=flr(cam_y)


	draw_snow()

	-- background elements	
	for pass=0,1 do
	camera()
	
	for el in all(ldat.bgelements) do	
		if (pass==0 and el.xyz[3]>1) or
		(pass==1 and el.xyz[3]<=1)
		then
		
			pal()
			if (el.cols) then
				for i=1,#el.cols, 2 do
					if (el.cols[i+1]==-1) then
						palt(el.cols[i],true)
					else
						pal(el.cols[i],el.cols[i+1])
					end
				end
			end
			
			local s=el.src
			local pixw=s[3] * 8
			local pixh=s[4] * 8
			local sx=el.xyz[1]
			if (el.dx) then
				sx += el.dx*t()
			end
			local sy=el.xyz[2]
						
			sx = (sx-cam_x)/el.xyz[3]
			sy = (sy-cam_y)/el.xyz[3]
			
			repeat
				map(s[1],s[2],sx,sy,s[3],s[4])					
				if (el.fill_up) then
					rectfill(sx,-1,sx+pixw-1,sy-1,el.fill_up)
				end
				if (el.fill_down) then
					rectfill(sx,sy+pixh,sx+pixw-1,128,el.fill_down)
				end
				sx+=pixw		
			until sx >= 128 or not el.xyz[4] 

			-- snow
			-- y = (sx-cam_x)/3
			-- x = (sy-cam_y)/3
			-- for i=0,106 do
			-- 	circfill(x+i, 1+flr(rnd(6)), 0.1, greguniverse.colors.red)			
			-- end
			-- circfill(1+flr(rnd(6)), 5, 0.1, greguniverse.colors.red)
		end
	end
	pal()	
		if (pass==0) then
			draw_z1(cam_x,cam_y)
		end
	end		
	
	clip()	
end
	

-- map and actors
function draw_z1(cam_x,cam_y)
	
	camera (cam_x,cam_y)
	pal(12,0)	-- 12 is transp
	map (0,0,0,0,128,64,0)
	-- pal()
	foreach(sparkle, draw_sparkle)
	for a in all(actor) do
		pal()
		if (a.hit_t>0 and a.t%4 < 2) then
			for i=1,15 do
				pal(i,8+(a.t/4)%4)
			end
		end
		a:draw() -- same as a.draw(a)
	end
	-- forground map
	map (0,0,0,0,128,64,1)
end


-->8
-- explosions

function bang_puff(mx,my,sp)

	local aa=rnd(1)
	for i=0,5 do
	
		local dx=cos(aa+i/6)/4
		local dy=sin(aa+i/6)/4
		local s=make_sparkle(
			sp,mx + dx, my + dy) 
		s.dx = dx
		s.dy = dy
		s.max_t=10
	end
	
end

function atomize_sprite(s,mx,my,col)

	local sx=(s%16)*8
	local sy=flr(s/16)*8
	local w=0.04
	
	for y=0,7 do
		for x=0,7 do
			if (sget(sx+x,sy+y)>0) then
				local q=make_sparkle(0,
					mx+x/8,
					my+y/8)
				q.dx=(x-3.5)/32 +rnd(w)-rnd(w)
				q.dy=(y-7)/32   +rnd(w)-rnd(w)
				q.max_t=20+rnd(20)
				q.t=rnd(10)
				q.spin=0.05+rnd(0.1)
				if (rnd(2)<1) q.spin*=-1
				q.ddy=0.01
				q.col=col or sget(sx+x,sy+y)
			end
		end
	end

end
-->8
-- camera

-- (camera y is lazy)
ccy_t=0
ccy  =0

-- splitscreen (multiplayer)
split=false

-- camera x for player i
function pl_camx(x,sw)
	return mid(0,x*8-sw/2,1024-sw)
end


function update_camera()

	local num=0
	if (alive(pl[1])) num+=1
	if (alive(pl[2])) num+=1
	
	split = num==2 and
		abs(pl_camx(pl[1].x,64) -
		    pl_camx(pl[2].x,64)) > 64
	
	-- camera y target changes
	-- when standing. quantize y
	-- into 2 blocks high so don't
	-- get small adjustments
	-- (should be in _update)
	
	if (num==2) then
		-- 2 active players: average y
		ccy_t=0
		for i=1,2 do
			ccy_t += (flr(pl[i].y/2+.5)*2-12)*3
		end
		ccy_t/=2
	else
	
		-- single: set target only
		-- when standing
		for i=1,#pl do
			if (alive(pl[i]) and
			    pl[i].standing) then
			    ccy_t=(
			     flr(pl[i].y/2+.5)*2-12
			    )*3
			end
		end
	end
	
	-- target always <= 0
	ccy_t=min(0,ccy_t)
	
	ccy = ccy*7/8+ccy_t*1/8
	cam_y = ccy
	
	local xx=0
	local qq=0
	for i=1,#pl do
			if (alive(pl[i])) then
				local q=1
				
				-- pan across when first
				-- player dies and not in
				-- split screen
				if (pl[i].life<=0 and pl[i].death_t) then
					q=time()-pl[i].death_t
					q=mid(0,1-q*2,1)
					q*=q
				end
				
				xx+=pl[i].x * q
				qq += q
			end
	end
	
	if (split) then
		cam_x = pl_camx(pl[1].x,64)
	elseif qq>0 then
		cam_x = pl_camx(xx/qq,128)
	end
	
end
-->8
-- actors

function init_actor_data()

function dummy() end

actor_dat=
{
	-- bridge builder
	[53]={
		ddy=0,
		friction=1,
		move=move_builder,
		draw=dummy
	},
	
	[64]={
		draw=draw_charge_powerup
	},
	
	[65]={
		draw=draw_exit
	},
	
	-- swirly
	[80]={
		life=2,
		frames=1,
		bounce=0,
		ddy=0, -- gravity
		move=move_swirly,
		draw=draw_swirly,
		can_bump=false,
		d=0.25,
		r=5 -- collisions
	},
	
	-- bouncy mushroom
	[82]={
		ddx=0,
		frames=1,
		active_t=0,
		move=move_mushroom
	},
	
	-- glitch mushroom
	[84]={
		draw=draw_glitch_mushroom
	},
	
	-- bird
	[93]={
		move=move_bird,
		draw=draw_bird,
		
		bounce=0,
		ddy=0.03,-- default:0.06
	},
	
	-- frog
	[96]={
		move=move_frog,
		draw=draw_frog,
		bounce=0,
		friction=1,
		tongue=0,
		tongue_t=0
	},
	
	[116]={
		draw=draw_tail
	}

}

end



function move_builder(a)
	
	local x,y=a.x,a.y-0.5
	local val=mget(x,y)
	if val==0 then
		mset(x,y,53)
	elseif val!=53
	then
		del(actor,a)
	end
	a.t += 1
	
	if (x<1 or x>126 or a.t > 30)
	then del(actor,a) end 
	
	for i=0,0.2,0.1 do
	local s=make_sparkle(
			104,a.x,a.y-0.5)   
	s.dx=cos(i+a.x/4)/8
	s.dy=sin(i+a.x/4)/8
	s.col=10
	s.max_t=10+rnd(10)
	end
	
	a.x+=a.dx
end

function move_frog(a)

	move_actor(a)
	
	if (a.life<=0) then
		bang_puff(a.x,a.y-0.5,104)
	end

	a.frame=0
	
	local p=closest_p(a,16)
	

	if (a.standing) then
		a.dy=0 a.dx=0
		
		-- jump
		
		if (rnd(20)<1 and
						a.tongue_t==0) then -- jump freq
			-- face player 2/3 times
			if rnd(3)<2 and p then
				a.d=sgn(p.x-a.x)
			end
			a.dy=-0.6-rnd(0.4)
			a.dx=a.d/4
			a.standing=false
			sfx(23)
		end
	else
		a.frame=1
	end
		
	-- move tongue
	
	-- stick tongue out when standing
	if a.tongue_t==0 and
				p and abs(a.x-p.x)<5 and
				rnd(20)<1 and
				a.standing then
		a.tongue_t=1
	end
	
	-- move active tongue
	if (a.tongue_t>0) then
		a.frame=2
		a.tongue_t = (a.tongue_t+1)%24
		local tlen = sin(a.tongue_t/48)*5
		a.tongue_x=a.x-tlen*a.d

		-- catch player		
		if not a.ha and p then
			local dx=p.x-a.tongue_x
			local dy=p.y-a.y
			if (dx*dx+dy*dy<0.7^2)
			then a.ha=p sfx(22) end
		end
		
		-- skip to retracting
		if (solid(a.tongue_x,
						a.y-.5) and 
				a.tongue_t < 11) then
				a.tongue_t = 24-a.tongue_t
		end
	end
	
	-- move caught actor
	if (a.ha) then
		if (a.tongue_t>0) then
			a.ha.x = a.tongue_x
			a.ha.y = a.y
		else
			a.ha=nil
		end
	end
	
	--a.tongue=1 -- tiles
	
	a.t += 1
end


function draw_frog(a)
	draw_actor(a)
	
	local sx=a.x*8+a.d*4
	local sy=a.y*8-3
	local d=a.d
	
	
	if (a.tongue_t==0 or not a.tongue_t) return
	
	local sx2=a.tongue_x*8
	local sy2=(a.y+0.25)*8
	line(sx,sy,sx2,sy,8)
	rectfill(sx2,sy,sx2+d,sy-1,14)
end

function draw_charge_powerup(a)
	--pal(6,13+(a.t/4)%3)
	draw_actor(a)
	local sx=a.x*8
	local sy=a.y*8-4
	for i=0,5 do
		circfill(
			sx+cos(i/6+time()/2)*5.5,
			sy+sin(i/6+time()/2)*5.5,
			(i+time()*3)%1.5,7)
		end
		
end

function move_mushroom(a)
	a.frame=0
	if (a.active_t>0) then
		a.active_t-=1
		a.frame=1
	end
end

function draw_glitch_mushroom(a)
	local sx=a.x*8
	local sy=a.y*8-4
	
	draw_actor(a)


	dx=cos(time()*5)*3
	dy=sin(time()*3)*3
	
	for y=sy-12,sy+12 do
	for x=sx-12,sx+12 do
		local d=sqrt((y-sy)^2+(x-sx)^2)
		if (d<12 and 
			cos(d/5-time()*2)>.4) then
		pset(x,y,pget(x+dx,y+dy)
		+rnd(1.5))
--  pset(x,y,rnd(16))
		end
	end
	end
	
	pset(sx,sy,rnd(16))
	
	draw_actor(a)
end

function draw_exit(a)
	local sx=a.x*8
	local sy=a.y*8-4
	
	sy += cos(time()/2)*1.5
	
	circfill(sx-1+cos(time()*1.5),sy,3.5+cos(time()),8)
	circfill(sx+1+cos(time()*1.3),sy,3.5+cos(time()),12)
	circfill(sx,sy,3,7)
	
	for i=0,3 do
		circfill(
			sx+cos(i/8+time()*.6)*6,
			sy+sin(i/5+time()*.4)*6,
			1.5+cos(i/7+time()),
			8+i%5)
		circfill(
			sx+cos(.5+i/7+time()*.9)*5,
			sy+sin(.5+i/9+time()*.7)*5,
			.5+cos(.5+i/7+time()),
			14+i%2)
	end
	
end


function turn_to(a,ta,spd)
	
	a %=1 
	ta%=1
	
	while (ta < a-.5) ta += 1
	while (ta > a+.5) ta -= 1
	
	if (ta > a) then
		a = min(ta, a + spd)
	else
		a = max(ta, a - spd)
	end
	
	return a
end

function move_swirly(a)

	-- dying
	if (a.life==0 and a.t%4==0) then
		
		local tail=a.tail[1] 
		local s=tail[#tail]
		
		local cols= {7,15,14,15}
		-- reuse
		atomize_sprite(64,s.x-.5,s.y-.5,cols[1+#tail%#cols])
		del(tail,s)
		if (s==a) del(actor,a)
		
	end
	
	local ah=a.holding
	
	if (ah and a.tail and a.tail[1][15]) then
		ah.x=a.tail[1][15].x
		ah.y=a.tail[1][15].y
		
		ah.dy=-0.1 -- don't land
		if (a.standing) ah.x-=a.d/2
		if (ah.life==0) a.holding=nil
	end
	
	a.t += 1
	if (a.hit_t>0) a.hit_t-=1
	
	if (a.t < 20) then
		a.dx *=.95
		a.dy *=.95
	end
	
	a.x+=a.dx
	a.y+=a.dy
	a.dx *=.95
	a.dy *=.95
	
	local tx=a.homex
	local ty=a.homey
	local p=closest_p(a,200)
	if (p) tx,ty=p.x,p.y
	
	-- local variation
	-- tx += cos(a.t/60)*3
	-- ty += sin(a.t/40)*3
	
	local turn_spd=1/60
	local accel = 1/64
		
	-- charge 3 seconds 
	-- swirl 3 seconds
	if ((a.t%360 < 180
		and a.life > 1) 
		or a.life==0) and
		abs(a.x-tx<12) then
		ty -= 6
	else
		-- heat-seeking
		-- instant turn, but inertia
		-- means still get swirls
		turn_spd=1/30
		accel=1/40
		if (abs(a.x-tx)>12)accel*=1.5
	end
	
	
	a.d=turn_to(a.d,
		atan2(tx-a.x,ty-a.y),
		turn_spd
	)
	

	a.dx += cos(a.d)*accel
	a.dy += sin(a.d)*accel
	
	-- spawn tail
	if (not a.tail) then
		a.tail={}
		for j=1,3 do
		
			a.tail[j]={}
			for i=1,15 do
				local r=5-i*4/15
				r=mid(1,r,4)
				local slen=r/9 + 0.3
				if (j>1) then
					r=r/3 slen=0.3
					--if (i==1) slen=0
				end
				
				local seg={
					x=a.x-cos(a.d)*i/8,
					y=a.y-sin(a.d)*i/8,
					r=r,slen=slen
				}
				
				add(a.tail[j],seg)
				
			end
			a.tail[j][0]=a
		end
		
	end
	
	-- move tail
	
	for j=1,3 do
		for i=1,#a.tail[j] do
			
			local s=a.tail[j][i]
			local h=a.tail[j][i-1]
			local slen=s.len
			local hx = h.x
			local hy = h.y
			
			if (i==1) then
				if (j==2) hx -=.5 --hy-=.7
				if (j==3) hx +=.5 --hy-=.7
			end
			
			local dx=hx-s.x
			local dy=hy-s.y
			
			local aa=atan2(dx,dy)
		
			if (j==2) aa=turn_to(aa,7/8,0.02)
			if (j==3) aa=turn_to(aa,3/8,0.02)
			s.x=hx-cos(aa)*s.slen
			s.y=hy-sin(aa)*s.slen
		end
	end
	
	-- players collide with tail
	
	for i=0,#a.tail[1] do	
	for pi=1,#pl do
		local p=pl[pi]
		if (alive(p) and a.life>0 and 
			p.life>0) then
			s = a.tail[1][i]
			local r=s.r/8 -- from pixels
			local dx=p.x-s.x
			local dy=(p.y-0.5)-s.y
			local dd=sqrt(dx*dx+dy*dy)
			local rr=0.5+r
			if (dd<0.5+r) then
				// janky bounce away
				local aa=atan2(dx,dy)
				aa+=rnd(0.4)-rnd(0.4)
				p.dx=cos(aa)/2
				p.dy=sin(aa)/2
				if (p.is_standing) p.dy=min(p.dy,-0.2)
			end
		end
		end
		end		
	
end


function draw_swirly(a)

	if (not a.tail) return
	
	for j=1,3 do
	for i=#a.tail[j],1,-1 do
		seg=a.tail[j][i]
		local sx=seg.x*8
		local sy=seg.y*8
		
		cols =  {7,15,14,15,7,7}
		cols2 = {6,14,8,14,6,6}
		local q= a.life==1 and 4 or 6
		local c=1+flr(i-time()*16)%q
		
		if (j>1) then
			if (i%2==0) then
			circfill(sx,sy,1,8)
			else
			pset(sx,sy,10)
			end
		else
			local r=seg.r+cos(i/8-time())/2
			r=mid(1,r,5)
			r=seg.r
			circfill(sx,sy+r/2,r,cols2[c])
			circfill(sx,sy,r,cols[c])
		end
		
	end
	end
	
	local sx=a.x*8
	local sy=a.y*8-4
	
	-- mouth
	spr(81,sx-4,sy+5+
		flr(cos(a.t/30)))
	-- head
	spr(80,sx-8,sy)
	spr(80,sx+0,sy,1,1,true)
-- 


end

function alive(a)
	if (not a) return false
	if (a.life <=0 and 
		(a.death_t and
			time() > a.death_t+0.5)
		) then return false end
	return true
end

-- ignore everything more than
-- 8 blocks away horizontally
function closest_a(a0,l,attr,maxdx)
	local best
	local best_d
	for i=1,#l do
		if not attr or l[i][attr] then
			local dx=l[i].x-a0.x
			local dy=l[i].y-a0.y
			d=dx*dx+dy*dy
			if (not best or d<best_d)
							and l[i]!=a0
							and l[i].life > 0
							and (not  maxdx or 
											abs(dx)<maxdx)
			then best=l[i] best_d=d end
		end
	end

	
	return best
end

function closest_p(a,dd)
	return closest_a(a,pl,nil,dd)
end


--[[
	birb
	follow player while close	
	collect 
	
]]
function move_bird(a)

--[[
	-- spawn with gem
	if (a.t==0) then
		gem=make_actor(67,a.x,a.y)
		a.holding=gem
	end
]]

	move_actor(a)
	
	local ah=a.holding
	
	if (ah) then
		ah.x=a.x
		ah.y=a.y+0x0.e
		ah.dy=0
		if (a.standing) ah.x-=a.d/2
		if (ah.life==0) then
			a.holding=nil 
			sfx(28) -- chirp
		end
	end
	
	local p=closest_p(a,12)
	
	dx=100 dy=100
	-- patrol home no target
	tx,ty=
		a.homex+cos(a.t/120)*6,
		a.homey+sin(a.t/160)*4
	
	if (p) tx,ty=p.x,p.y-3
	
	local a2
	
	if (not a.holding) then
		a2=closest_a(a,actor,"is_pickup")
		if a2 and abs(a2.x-a.x)<4 and
					abs(a2.y-a.y)<4 then
			p=nil -- ignore player
			tx,ty=a2.x,a2.y
			if (a.standing) a.dy=-0.1
		else
			a2=nil -- ignore if far
		end
	end

	local dx,dy=tx-a.x,ty-a.y 
	local dd=sqrt(dx*dx+dy*dy)
		
	if (p) then
		if (dd<0.5) a.holding=p
		if (a.holding==p) then
			if (btn(4,p.id) or btn(5,p.id)) a.holding=nil
			a.d=p.d
		end
	end
	
	if (a.t%8==0) a.d=sgn(dx)
	
	if (a.standing) then
		a.frame=0
		
		-- jump to start flying
		if (not solid(a.x,a.y+.2))a.dy=-0.2
		if (p and dd<5) a.dy=-0.3
		
		a.dx=0
		
	else
		-- flying
		local tt=a.t%12
		a.frame=1+tt/6
		-- flap
		if (tt==6) then
			local mag=.3 -- slowly decend
			
			-- fly up
			if (dd<4 and a.y>ty) mag=.4
			
			-- wall: fly to top
			if (a.hit_wall)mag=.45
			
			-- player can shoo upwards
			if (p and a.y>ty and not ah) mag=.45
			
			a.hit_wall = false
			a.dy-=mag
		end
	
		
		if (a.dy<0.2) then
			a.dx+=a.d/64
		end
		
	end
	
	a.frame=a.standing and 0 or
			1+(a.t/4)%2

end


function draw_bird(a)
	local q=flr(a.t/8)
	if ((q^2)%11<1) pal(1,15)
	
	draw_actor(a)
	
	-- debug: show target
	--[[
	if (a.tx) then
		local sx=a.tx*8
		local sy=a.ty*8
		circfill(sx,sy,1,rnd(16))
	end
	]]
end
-->8
-- themes (backgrounds)


theme_dat={

[1]={
	sky={1},
	bgelements={	
		-- clouds
		{		
			src={16,56,16,8},
			xyz = {0,10*4,4,true},
			dx=-8,
			cols={15,47,1,-1},
			fill_down = 12
		},
		-- mountains
		{
			src={0,56,16,8},
			xyz = {0,10*4,4,true},
			fill_down=5,
		}

		-- -- leaves: dark (foreground)
		-- {
		-- 	src={32,48,16,6},
		-- 	xyz = {0,2,0.8,true},
		-- 	dx=-0.9,
		-- 	cols={3,greguniverse.colors.light_peach},
		-- 	fill_up=greguniverse.colors.light_peach
		-- }		
	}
},

--------------------------
-- level 2

[2]={
	sky={12},
	bgelements={		
		-- gardens
		{
			src={32,56,16,8},
			xyz = {0,100,4,true},
			--cols={7,6,15,6},
			cols={3,13,7,13,10,13,1,13,11,13,9,13,14,13,15,13,2,13},
			
			fill_down=13
		},
		-- foreground shrubbery
		{
			src={16,56,16,8},
			xyz = {0,64*0.8,0.6,true},
			cols={15,1,7,1},
			fill_down = 12
		},
		-- foreground shrubbery feature
		{
			src={32,56,8,8},
			xyz = {60,60*0.9,0.8,false},
			cols={15,1,7,1,3,1,11,1,10,1,9,1},
		},
		-- foreground shrubbery feature
		{
			src={32,56,8,8},
			xyz = {260,60*0.9,0.8,false},
			cols={15,1,7,1,3,1,11,1,10,1,9,1},
		},	
		-- leaves: indigo
		{src={32,48,16,6},
			xyz = {40,64,4,true},
			cols={1,13,3,13},
			fill_up=13
		},	
		-- leaves: light
		{src={32,48,16,6},
			xyz = {0,-4,1.5,true},
			cols={1,3},
			fill_up=1
		},	
		-- leaves: dark (foreground)
		{src={32,48,16,6},
			xyz = {-40,-6,0.8,true},
			cols={3,1},
			fill_up=1
		}	
	},
},
	----------------

-- double mountains

[3]={
	sky={12,14,14,14,14},
		bgelements={
			-- mountains indigo (far)
			{
				src={0,56,16,8},
				xyz = {-64,30,8,true},
				fill_down=13,
				cols={6,15,13,6}
			},	
			-- clouds inbetween
			{
				src={16,56,16,8},
				xyz = {0,50,8,true},
				dx=-30,
				cols={15,7,1,-1},
				fill_down = 7
			},	
			-- mountains close
			{
				src={0,56,16,8},
				xyz = {0,140,8,true},
				fill_down=13,
				cols={6,5,13,1}
			}
		}
	}
}

actor = {}
sparkle = {}
pl = {}
loot = {}

function init_level(lev)

	level=lev
	level_t = 0
	death_t = 0
	finished_t = 0
	gems = 0
	gem_sfx = {}
	total_gems = 0
	glitch_mushroom = false
	
	music(-1)

	if play_music then
		if (level==1) music(0)	
	end

	reload()
	
	if (level <= 4) then
	-- copy section of map
	memcpy(0x2000,
			0x1000+((lev+1)%4)*0x800,
			0x800)
	end
	
	-- spawn player
	for y=0,15 do for x=0,127 do
	
		local val=mget(x,y)
		
		if (val == 72) then
			clear_cel(x,y)
			pl[1] = make_player(72, x+0.5,y+0.5,1)			
			if (num_players==2) then
				pl[2] = make_player(88, x+2,y+1,1)
				pl[2].id = 1
			end
			
		end
		
		-- count gems
		if (val==67) then
			total_gems+=1
		end
		
		-- lootboxes
		if (val==48) then
			add(loot,67)
		end
	end end
	
	local num_booby=0
	-- shuffle lootboxes
	if (#loot > 1) then
		-- ~25% are booby prizes
		num_booby=flr((#loot+2) / 4)
		for i=1,num_booby do
			loot[i]=96
			if (rnd(10)<1) then
				loot[i]=84 -- mushroom
			end
		end
		
		-- shuffle
		for i=1,#loot do
			-- swap 2 random items
			j=flr(rnd(#loot))+1
			k=flr(rnd(#loot))+1
			loot[j],loot[k]=loot[k],loot[j]
		end
	end
	
	total_gems+= #loot-num_booby
	
	
	if (not pl[1]) then
		pl[1] = make_player(72,4,4,1)
	end

end

-->8
-- draw died / finished

function draw_finished(tt)

	if (tt < 15) return
	tt -= 15

	local str="★ stage clear ★  "
	
	print(str,64-#str*2,31,14)
	print(str,64-#str*2,30,7)
	
	-- gems
	local n = total_gems
	
	for i=1,15 do pal(i,13) end
	for pass=0,1 do
		for i=0,n-1 do
			t2=tt-(i*4+15)
			q=i<gems and t2>=0
			if (pass == 0 or q) then
				local y=50-pass
				if (q) then
						y+=sin(t2/8)*4/(t2/2)
						-- if (not gem_sfx[i]) sfx(greguniverse.sfx.gem_total)
						gem_sfx[i]=true
				end				
				spr(67,64-n*4+i*8,y)				
			end
		end	
		pal()
	end
	
	if (tt > 45) then
		print("❎ continue",42,91,12)
		print("❎ continue",42,90,7)
	end
	
end

__gfx__
0000000022222222444444447777777700000000000aa000d7777777d66667d666666667d6666667cccccccccccccccccc5ccccccc5cccc5f777777767766666
0000000022222222444444446666666600000000000990002999999f5d66765d666666765d666676ccccccccccccccc5c55555ccc5555555effffff7d6766666
0000000022222222444444443333333300000000a97770002999999f55dd6655dddddd6655dddd66cccccccccccccc5555555ccc55555555effffff7dd666666
0000000022222222444444443333333300007700a97779a02997799f55dd6655dddddd6655dddd66ccccccccccccc555c555ccccc5555555eeeeeeef66666666
0000000022222222444444443332332200088080007779a02977779f55dd6655dddddd6655dddd66cccccccccccccc5ccc5ccccccc5ccc5c5555555566666776
0000000022222222444444443322322200070080009900002997799f55dd6655dddddd6655dddd66ccccccccccc5555555cccccc5555c555dddddddd6666d676
00000000222222224444444432422442bb08000000aa00002999999f5111d651111111d6511111d6cccccccccc55c5555ccccccc55555555ddddd6dd6666dd66
000000002222222244444444244444420b370000000300002222222d11111d111111111d1111111dccccccccc5555555cccccccc5555c5556666666666666666
00700070555ddd661010122244440404003800000000000000000000000b000000333300000000000004400000044000000b0000000550006666666666666666
0070007055dd6667111012224444044400070bb00000000000000000000b000003333330444444440044240000bb2400000b3000000550006666660000666666
0d7d0d7dc5d6667c010011244444240000083b000000000000eff700000b000033333333414114249444424994223249000b3000000550006666000000006666
06760777c5d6667c01111222444424000007300000000000002eef00000b000033333b33444444442494444224942342000b00000005d0006660000000000666
11151115cc5667cc00001222444400000008000000000000002eef00b00b000033333333422414140049440000494300000b00000005d0006600000000000066
51555155cc5667cc0000112444444000000700000000000000222e000b0b00b03b333333444444440004400000b44000003b00000005d0006600000000000066
55555555ccc67ccc00012222244444000008000000000000000000000b0b0b0033333333000440000000000000030000003b00000005d0006000000000000006
55555555ccc67ccc00111112244444400007000000000000000000000b0b0b00333333330004400000000000000b0000000b00000005d0006000000000000006
44444444444444444444444444444444444444440000000033333333333333333333333377777777000000000000000000000000000000008eeeeee800666600
2244224444444444444444444466444444d6644400000000333333333333b3333333333377777777000000000000000000000000000dd000288888880d666670
42244224444224444484344442d6744442dd6744000000003339a3333333bab3333333337377737700000000000000000000000000dd770022222222dd666676
44224424444422444727334422dd664422dd664400707000339a7a33333bbb3333333333333733370000000000000000000000000ccd77d011111111dd111176
24422444422442244223844422ddd66422dd6644000e00003399a93333333b3333333333373337330000000000000000000000000cccddd01221122111111111
22442244442244444442274422dddd6422dddd4400737000bbb99bbb3b33333333333333777377730000000000000000000000000cdccdd022882288111cc111
4224422444422444444422842222224442222244000b0000bbbbbbbb33333333333333337777777700000000000000000000000000c2cc0022e822e8cccccccc
4444444444444444444442244444444444444444000b0000bbbbbbbbbbbbbbbb3333333377777777000000000000000000000000000cc000212e212ec55ddddc
d777777760066006c1dddd66c1dddd77cccccccc0099970000077777777770000000000770000000000000077000000067766666cccccccc1281128155d6667d
2eeeeeef00000000c1555566c1555567cc1111cca994497a000777777777700000000007700000000000000770000000d6766666cccccccc22882288dd666676
2eeaeeef00000000c1555576c15555661155551109a00490007777777777770000000077770000000000007777000000dd666666cccccccc22e822e8dd666676
2aaaaaef00000000c1515576c15555661155551da49aa99a00773777377737000000003773000000000000777700000066667776cc0cc0cc212e212edd666676
2eaaaeef00000000c15d1176c1555566115555dd00499900037333733373337000000733337000000000077777700000666d6676cccccccc12811281dd111176
2eaeaeef00000000c155d166c1555566115555d600044000733373337333733300000773377000000000077777700000666d6676ccc00ccc22882288d1111116
2eeeeeef00000000c1555566c15555661155556600000000773777377737773700007777777700000000777777770000666ddd660c0000c022e822e8111cc111
2222222d00000000c1111116c1111116111111dd0000000077777777777777770000777777770000000077777777000066666666c000000c211e211e11cccc11
0066660000000000000000000000000000000000000000000000000000000000000000000000000000eeee0000eeee00000000000eeeeee000eeee0000eeee00
0600006000f0800000000000000ef0000000000000000000000000000000000000eeee0000eeee00eeeeeeeeeeeeeeee000eeee0eeeeeeee0eeeeee0eeeeeeee
6009800600000090be82887700ed7f00000a00000000000000007000000000000eeeeee00eeeeee0eeececeeeeececee0eeeeeeeeee1e1eeeeececeeeeececee
60a77f060e077000be8828eb0edef7f00aaaaa00000770000007070000070000eeececeeeeececeeee81e18e0e81e1800ee11eeeee8eee8eee81e18e0e81e180
60b77e06000770a0bfe88efb0f7fede000aaa000000770000000700000007000ee81e18eee81e18e0eeeeee00eeeeee00eeee22eeeeeeeee0eeeeee00eeeeee0
600cd0060d0000000bfeefb000f7de0000a0a000000000000000000000000000eeeeeeeeeeeeeeee0eeee8888eeeeee000e8e22eeeee2eee8eeeeee08eeeeee0
06000060000c0b0000bbbb00000fe000000000000000000000000000000000000eeeeee00eeee888888808888888088808eeeee00eeeeee08880888088808880
00666600000000000000000000000000000000000000000000000000000000008888088808880888888800000000088808880880888008880000000000000000
0777008000000000000000000077ee0000baa70000000000000000000000000077fffff777fffffffffffff700000000000000000080000000000000008fff00
00077687000000000077ee000eeeeee00bbab7700000000000000000000007000777777007ffffffffffff770000000000000000000fff000008fff0000f1f00
00072777022222200eeeeee00eeeeff00aaabba00007000000700700070000000077000007ffffff77fff7700000000000000000000f1f000900f1f0000fffa0
0707877702222220eeeeeffe0eeeeff0aabaaaaa0000070000000000000000000000000007777ff777ff77000000000000000000000fffa00490fffa00992000
0077777707888870eeeeeffe0eeeeee09999999900700000000000000000000000000000000077ff7f7777000000000000000000090990000449990009999400
0006675700777700888888880888888000088000000070000070070000000070000000000000077777700000000000000000000000a999000049990000aa9440
006006770000000000222200002222000008e00000000000000000000070000000000000000000000000000000000000000000000aa9990000099000002a0040
000000660000000000eeee0000eeee00000ee0000000000000000000000000000000000000000000000000000000000000000000000200000002000000000000
000000000000bb3b0000000000000000000000000000000000000000000000000000000000000007777777770000000000000000444444440000011001100000
00000000000bb2b200000000000aa000000000000000000000000000000000000000000000000077577777755000000000000000444444440111007777111000
00000000007bbbbb0000bb3b00999700000000000000000000000000000000000000700000000775557577555500000000000000544444550011177ff7770000
0000bb3b07bb3300000bb2b20994497000000000000000000000000000000000000777000000777555747475550000000000000055444455000177fff7ff7110
0bbbb2b20bb330b00b7bbbbb49a0049a00000000000000000000000000000000000070000007777555544455555000000000000055554555017777fffffff711
b77bbbbbbb330000b7bb2288049aa990000000000000000000000000000000000000000000777755555455555555000000000000555555550777777fffff7710
bbbb33000b0b0000bbbb3330004999000000000000000000000000000000000000000000077575555555555555555000000000005555555517fff77fffff7770
3300b0bbb0b000003300b0bb000440000000000000000000000000000000000000000000745745555555555555555550000000005555555577ffffffffffff77
00008ee0000ee00000e80000000e800007676767007666700007670000676760000000044444444444445555555555555000000055555554ffffffff00000000
0000800000008000000080000000800000005000000050000000500000005000000000444444444444445555555555555500000055555554ffffffff00000000
0077770000777700007777000077770000777700007777000077770000777700000000444444444444455555555555555550000055555544ffffffff00000000
0777777007777770077777700777777007777770077777700777777007777770000044444444444444455555555555555555000055555444ffffffff00000000
0717771007177710071777100717771007177710071777100717771007177710000444444444444444455555555555555555500055555444ffffffff00000000
0777777007777770077777700777777007777770077777700777777007777770004445444444444444555555555555555555550055555544ffffffff00000000
099999900999999777999997779999900eeeeee00eeeeee00eeeeee00eeeeee0044454444444444445555555555555555555555055555544ffffffff00000000
077007707700000000000000000000770a00a000a000a000a00a00000a0a0000454444444444444445555555555555555555555555555554ffffffff00000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777700007770000077700000777000007070000007700000707000d200000000000000d50000000000000000d2000000000000000000000000000000000000
00777700007000000070700000707000007070000070000000707000000000000000000000000000000000000000000000000000000000000000000000000000
00700700007700000077000000770000007770000070000000777000f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2f2000000000000000000000000d20000000000
00700700007000000070700000707000000070000070000000707000000000050000000034000000000000000000000000000000000000003400000000000000
00700700007770000070700000707000007770000007700000707000f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3000000000000000000000000d13400000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0b0000000000000000000000000e0e0e0e0e0e0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000007770000007700000777000007777000077700000077000a0a0d3a0a0a0a0a0d3a0a0a0a0a0d3a0b0d0000000000000000000000000f1f0f0f0f0f0
0070700000070000007000000007000000777700007070000070000000000000000000e0e0e00000000000000000000000000000000000e0e0e0000000000000
00770000000700000077700000070000007007000077700000777000a0b000a0a0a0a0b000a0a0a0a0b000b0d0d005000000000000000000000000f1f0f0f0f0
0070700000070000000070000007000000700700007070000000700000000000000000f1f0e1000000000000000000000000e0e0000000f1f0e1000000e0e000
00707000007770000077000000070000007007000070700000770000b0d000a0a0a0b0d000a0a0a0b0d000d0d0d00000000000000000000000000000f1f0f0f0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d0d0c0a0a0b0d0d0c0a0a0b0d0d0d0d0d0d0000000000000000000000000000000a0a0a0
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0e00000000000000000000000000000000000
0000e0e0000000000000000000000000000000000000000000000000d0c0a0a0b0d0d0c0a0a0b0d0d0d0d0d0d0d0000000000000000000000000000000a0a0a0
00000000000000000000000000000000000000000000000000000000000000e0e0e0e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e00000000300000000000000a0a0a0
00810000000000000000000000000000000000000000000000000000000000f0f0f0f0f0f0f0f0f0f0f000000000000000000000000000000000000000000000
000000000000000000000000000000000000d2000000000000f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0e1d100000000000000000000000000a0a0a0
828200000000000000000000000000e0e0e0e0e0e0e0e0e0e0e0e0e0e0e000f1f0f0f0e100f1f0f0f0e100000000000000000000000000000000000000000000
000000000000000000000000000000000000d1000000e0e0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f000d100000000000000000000000000a014a0
840000000036000000000000000000f0c3f0f0f0f0f0f0f0f0f0f0f0f0f00000f0f0f0000000f0f0f00000000000000000000000000000003600000000000000
000000000000000000000000000000000000d1000000f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f000d10000000000000000d200000000a0a0a0
e0e0e0e0e0e0000000000000000000f0f0e10000f1f0c3e10000f1f0f0e10000f0f0f0000000f0f0f0000000003400340000000000000000e000000000000000
000000000000000034003400000000000000e0e0e0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f1f0e100d10000000000000000d1000000e0e0e0e0
f0f0c3f0f0f0000000000000000000c3f000000000f0f000000000f0f0000000f0f0f0000000f0f0f0000000e0e0e0e0e000000000000000f000000000000000
00000000000000e0e0e0e0e0000000000000f0e100f1f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f000d10000d10000000000000000e0e0e0e0f0f0f0f0
c3f0f0f0f0f0000000000000000000f0f000000000f0f000000000f0f0000000f0f0f0000000f0f0f0000000f1f0f0f0e100000000000000f000000000000000
00000000000000f1f0f0f0e1000000000000d1000000f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f000d10000d10000000000000000f1f0f0f0f0f0f0f0
0000000000000000000000000000000000000000000000000000000000000000e48282828282828282828282828282f400cccc000088880000ffff0000222200
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc00cc0088008800ff00ff002200220
000000000000000000000000000000000000000000000000000000000000000000e482828282828282828282f4e4f400cc0cc0cc88088088ff0ff0ff22022022
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0cccc0c80888808f0ffff0f20222202
00000000000000000000000000000000000000000000000000000000000000000000d4d4e4f4d4e48282f4d400000000c01ccc0c80e88808f09fff0f20722202
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0cccc0c80888808f0ffff0f20222202
00000000000000000000000000000000000000000000000000000000000000000000000000000000e4f4000000000000c0cccc0c80888808f0ffff0f20222202
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0cccc0c80888808f0ffff0f20222202
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0cc1c0c8088e808f0ff9f0f20227202
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0c1cc0c808e8808f0f9ff0f20272202
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0cccc0c80888808f0ffff0f20222202
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0cccc0c80888808f0ffff0f20222202
840000000000000000000000009100000000000000000000002400000000000000000000000000000000000000000000c0cccc0c80888808f0ffff0f20222202
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c01cc10c80e88e08f09ff90f20722702
131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313131313c0cccc0c80888808f0ffff0f20222202
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0cccc0c80888808f0ffff0f20222202
00000000000000000000000000000000000000000000000000000000000000000000000000000000820000000000828200bbbb00000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bb00bb0000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000008200000000008282bb0bb0bb000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0bbbb0b000000000000000000000000
0000000000000000000000000000000000000000e6f60000000000000000000000000000000000008200000000008282b03bbb0b000007777777000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0bbbb0b000777777777700000000000
0000000000000096b60000000000000000e6f6e6e7e7f600000000000000000000000000005200008252007152008282b0bbbb0b077777777777770000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0bbbb0b777777777777777700000000
000096c7000087a7b7b696b6000096b6e6e7e7e7e7e7e7f6e6f60000e6f6000000000000524100008241009341e68282b0bb3b0b000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0b3bb0b000000000000000000000000
b687a7b7b68797a7b7b7b7b7b687a7b7e7e7e7e7e7e7e7e7e7e7f6e6e7e7f6e671000000419371e68293f68282828282b0bbbb0b000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0bbbb0b000000000000000000000000
d797a7b7b7d6d6b7b7b7b7b7b7b7b7b7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e79393f6e6938293828282827282828282b0bbbb0b000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b03bb30b000000000000000000000000
b7d6b7b7b7b7b7b7b7b7b7b7b7b7b7b7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e7e762828282827282828282828282828282b0bbbb0b000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b0bbbb0b000000000000000000000000
__label__
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000088008880888080800880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000080808000808080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000080808800880080808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000080808000808080808080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000088808880888008808880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000880080800000888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000808080800000808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000808008000000808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000808080800000808000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
7000000000000000888080800000888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000880080800000888000008880888088800000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000808080800000808000008080800000800000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000808088800000808000008080888000800000000000000000000000000000000000000000000000000000000000000000000000000000000d
7000000000000000808000800000808000008080008000800000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000888088800000888008008880888000800000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000888088008080888080008880000088808880800008808880000000000000000000000000000000000000000000000000000000000000000d
d000000000000000080080808080808080008000000080008080800080008000000000000000000000000000000000000000000000000000000000000000000d
7000000000000000080080808880888080008800000088008880800088808800000000000000000000000000000000000000000000000000000000000000000d
d000000000000000080080808080808080008000000080008080800000808000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000888080808080808088808880000080008080888088008880000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000088088808880880088008880880008800000000000008880888080808880000000000000000000000000000000000000000000000000000d
7000000000000000800008008080808080800800808080000000000000000800808080808000000000000000000000000000000000000000000000000000000d
d000000000000000888008008880808080800800808080000000000000000800880080808800000000000000000000000000000000000000000000000000000d
d000000000000000008008008080808080800800808080800000000000000800808080808000000000000000000000000000000000000000000000000000000d
d000000000000000880008008080808088808880808088800800080000000800808008808880000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d
7777777fffffffffffffffffffff777ddddddddd7ddddddddd7ddddddd7777555555dd7ddddddddd7ddddddddd7ddddddddd7ddddddddd7dd777777fffff77dd
d7fff7777fffffffffffffffffff777dddddddddddddddddddddddddd775755555555dddddddddddddddddddddddddddddddddddddddddddd7fff77fffff777d
77fffff77fffffffffffffffffffff77dddddddddddddddddddddddd745745555555555ddddddddddddddddddddddddddddddddddddddddd77ffffffffffff77
ffffff7777fffffffffffff75fffffffddddddddddddddddddddddd44444555555555555ddddddddddddddd7ddddddddddddddddddddddddfffffff7ffffffff
ffffff7777ffffffffffff7755ffffff77dddddddddddd7777dddd4444445555555555555ddddd7777dddd775ddddddddddddddddddddd77ffffff775fffffff
fffff777777ffffffffff775555ffffff777dddd7dddd77ff777dd44444555555555555555ddd77ff777d775557ddddddddd7dddddddd77ffffff77555ffffff
fffff777777fffffffff77755555fffff7ff7ddddddd77fff7ff4444444555555555555555dd77fff7ff777555dddddddddddddddddd77ffffff777555ffffff
ffff77777777fffffff7777555555ffffffff7dddd7777fffff444444445555555555555555777fffff77775555ddddddddddddddd7777fffff77775555fffff
ffff77777777ffffff777755555555ffffff77ddd777777fff44454444555555555555555555777fff7777555555ddddddddddddd777777fff7777555555ffff
fff7777777777ffff77575555555555fffff777dd7fff77ff444544445555555555555555555577ff775755555555dddddddddddd7fff77ff775755555555fff
fff7777777777fff7457455555555555ffffff7777ffffff4544444445555555555555555555555f745745555555555ddddd7ddd77ffffff745745555555555f
ff777777777777f44444555555555555fffffffffffffff4444444444444555555555555555555555555555555555555ddddddddfffffff44444555555555555
5f7737773777374444445555555555555fffffffffffff444444444444445555555555555555555555555555555555555ddddd77ffffff444444555555555555
5373337333733374444555555555555555ffffffffffff4444444444444555555555555555555555555555555555555555ddd77fffffff444445555555555555
7333733373337333444555555555555555ffffffffff444444444444444555555555555555555555555555555555555555dd77ffffff44444445555555555555
77377737773777374445555555555555555ffffffff44444444444444445555555555555555555555555555555555555555777fffff444444445555555555555
777777777777777744555555555555555555ffffff4445444444444444555555555555555555555555555555555555555555777fff4445444455555555555555
7777777777777777755555555555555555555ffff44454444444444445555555555555555555555555555555555555555555577ff44454444555555555555555
777777777777777775555555555555555555555f454444444444444445555555555555555555555555555555555555555555555f454444444555555555555555
73777377737773777744555555555555555555554444444444444444555555555555555555555555555555555555555555555555555555555555555555555555
33373337333733377344555555555555555555554444444444444444555555555555555555555555555555555555555555555555555555555555555555555555
37333733373337333375555555555555555555555444445554444455555555555555555555555555555555555555555555555555555555555555555555555555
77737773777377733775555555555555555555555544445555444455555555555555555555555555555555555555555555555555555555555555555555555555
77777777777777777777555555555555555555555555455555554555555555555555555555555555555555555555555555555555555555555555555555555555
77777777777777777777555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
77777777777777777777755555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
77777777777777777777755555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
73777377737773777777775555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
33373337333733373777375555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
37333733373337333373337555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
77737773777377737333733355555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
77777777777777777737773755555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
77777777777777777777777755555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
77777777777777777777755555555555555555555555555555cccc55555555555555555555555555555555555555555555555555555555555555555555555555
7777777777777777777775555555555555555555555555555cc55cc5555555555555555555555555555555555555555555555555555555555555555555555555
737773777377737777777755555555555555555555555555cc5cc5cc555555555555555555555555555555555555555555555555555555555555555555555555
333733373337333737773755555555555555555555555555c5cccc5c555555555555555555555555555555555555555555555555555555555555555555555555
373337333733373333733375555555555555555555555555c51ccc5c555555555555555555555555555555555555555555555555555555555555555555555555
777377737773777373337333555555555555555555555555c5cccc5c555555555555555555555555555555555555555555555555555555555555555555555555
777777777777777777377737555555555555555555555555c5cccc5c555555555555555555555555555555555555555555555555555555555555555555555555
777777777777777777777777555555555555555555555555c5cccc5c555555555555555555555555555555555555555555555555555555555555555555555555
777777777777777777777555555555555555555555555555c5cc1c5c5555555555555555555555555555555555bbbb5555555555555555555555555555555555
777777777777777777777555555555555555555555555555c5c1cc5c555555555555555555555555555555555bb55bb555555555555555555555555555555555
737773777377737777777755555555555555555555555555c5cccc5c55555555555555555555555555555555bb5bb5bb555555555555a5555555a5555555a555
333733373337333737773755555555555555555555555555c5cccc5c55555555555555555555555555555555b5bbbb5b5555555555aaaaa555aaaaa555aaaaa5
373337333733373333733375555555555555555555555555c5cccc5c55555555555555555555555555555555b53bbb5b55555555555aaa55555aaa55555aaa55
777377737773777373337333555555555555555555555555c51cc15c55555555555555555555555555555555b5bbbb5b55555555555a5a55555a5a55555a5a55
777777777777777777377737555555555555555555555555c5cccc5c55555555555555555555555555555555b5bbbb5b55555555555555555555555555555555
777777777777777777777777555555555555555555555555c5cccc5c55555555555555555555555555555555b5bbbb5b55555555555555555555555555555555
777777777777777777777555555555555555555555555555c5cc1c5c55555555555555555588885555555555b5bb3b5b55555555555555555555555555555555
777777777777777777777555555555555555555555555555c5c1cc5c55555555555555555885588555555555b5b3bb5b55555555555555555555555555555555
737773777377737777777755555555555555555555555555c5cccc5c55555555555555558858858855555555b5bbbb5b55555555555555555555555555555555
333733373337333737773755555555555555555555555555c5cccc5c55555555555555558588885855555555b5bbbb5b55555555555555555555555555555555
373337333733373333733375555555555555555555555555c5cccc5c555555555555555585e8885855555555b5bbbb5b55555555555555555555555555555555
777377737773777373337333555555555555555555555555c51cc15c55555555555555558588885855555555b53bb35b55555555555555555555555555555555
777777777777777777377737555555555555555555555555c5cccc5c55555555555555558588885855555555b5bbbb5b55555555555555555555555555555555
777777777777777777777777555555555555555555555555c5cccc5c55555555555555558588885855555555b5bbbb5b55555555555555555555555555555555
151512224444545455555555555555555555555555555555c5cc1c5c55555555555555558588e85855555555b5bb3b5b5555555555555555d777777755555555
1115122244445444555555555555555555eeee5555555555c5c1cc5c5555555555555555858e885855555555b5b3bb5b55555555555555552999999f55555555
515511244444245555555555555555555eeeeee555555555c5cccc5c55555555555555558588885855555555b5bbbb5b55555555555555552999999f55555555
51111222444424555555555555555555eeececee55555555c5cccc5c55555555555555558588885855555555b5bbbb5b55555555555555552997799f55555555
55551222444455555555555555555555ee81e18e55555555c5cccc5c55555555555555558588885855555555b5bbbb5b55555555555555552977779f55555555
55551124444445555555555555555555eeeeeeee55555555c51cc15c555555555555555585e88e5855555555b53bb35b55555555555555552997799f55555555
555122222444445555555555555555555eeeeee555555555c5cccc5c55555555555555558588885855555555b5bbbb5b55555555555555552999999f55555555
551111122444444555555555555555558888588855555555c5cccc5c55555555555555558588885855555555b5bbbb5b55555555555555552222222d55555555
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33323322333233223332332233323322333233223332332233323322333233223332332233323322333233223332332233323322333233223332332233323322
33223222332232223322322233223222332232223322322233223222332232223322322233223222332232223322322233223222332232223322322233223222
32422442324224423242244232422442324224423242244232422442324224423242244232422442324224423242244232422442324224423242244232422442
24444442244444422444444224444442244444422444444224444442244444422444444224444442244444422444444224444442244444422444444224444442
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
22442244444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
42244224444444444444444444444444444444444442244444444444444444444444444444444444444444444444444444444444444444444484344444444444
44224424444444444444444444444444444444444444224444444444444444444444444444444444444444444444444444444444444444444727334444444444
24422444444444444444444444444444444444444224422444444444444444444444444444444444444444444444444444444444444444444223844444444444
22442244444444444444444444444444444444444422444444444444444444444444444444444444444444444444444444444444444444444442274444444444
42244224444444444444444444444444444444444442244444444444444444444444444444444444444444444444444444444444444444444444228444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444422444444444
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b000000000
00000000000000000003330003330003330003330003330003330000000000000000000000000000000000000000000000000000000000000000000b00000000
0000000000000000003333303333303333303333303333303333300000000000000000000000000000000000000000000000000000000000000000b000000000
00000000000000000033333033333033333033333033333033333000000000000000000000000000000000000000000000000000000000000000000b00000000
0000000000000000003333303333303333303333303333303333300000000000000000000000000000000000000000000000000000000000000000b000000000
00000000000000000003330003330003330003330003330003330000000000000000000000000000000000000000000000000000000000000000000b00000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b000000000

__gff__
00020202000012020202000000000202020200000000020000000202000000000202020202000000000042420000020212420202020200000000424202000202607060607000000000000000a000000020022000600000000000000000200000a000006000a0a0a00000000000000000a0000808b00000000000000000000001
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000010000000000000000000000000000000001010000000000000000000000000000000000
__map__
00000000000000000000000000000000000000004444444444444444444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d0900090009000943000000000000000000000000000000000000000000000000002828
0000000000000000000000000000000000000000440808080808080808440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090907080909090909000000000000000000000000000000000000000000000000002828
000000000000000000000000000000000000000044080a0a400a0b7008440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090a0a0a0a0a0a0a0a000000000000000000000000000000000000000000000018002828
000000000000000000000000000000000000000044080a0a0a0b0d0d08440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000090a0a0a0a0a0a0a0b000000004400000000000000000000000000000043001828182828
0000000000000000000000000000000000000000000808080808080808000000000000000000003a3b00000000000000444400000000000000000000000000000000000000000000000000000000000043000000000000000000000009700a0a0a0a0a0b0d000000443044000000000000000000000000700000002828282828
3a3b000000000000000000000000000000003a3b0000000000000000000000000000000000000036370000000000000044440000000000000000000000000000000000000000000000003a3b00000000000000000000000000000000090a0a0a0a0a0b0d0d000000004400000000000000000000000000000018002828282828
36370000000000000000000000000000000036370000000000000000000000003a3b00000000382929390000cc7400004444000000000000000000000000000000000000000000000000363700000000000000000000000000000000090a0a0a0a0b0d0d0d000000004400000000000000000000000000000028182828412828
292939000000000000000000000000000038292939000000000000ce00000000363700000000382929390000dc000000000000000000000000000000000000000000000000000000003829293900cc00000000000000000000000000090a0a0a0b0d0d0c090000000044003a3b00000000000000000000180028282828282828
292937000000000000000000000000000036292937000000000000de00000038292939000000382929390000dc00ec00000000000000000000000000000000000000000000000000003629293700dc0000000000000000000000000009070809090708090900000000000036370000000000000000000028002828280e0e0e28
292937000000000000000000000000000036292937000000000000de00000038292939000000001213000000dc00fc0000004444000000cc00004444000044440000000000000000003629293700dc00000000000000000000000000030303030303030303030300000038292939000000cc0000000018281803030303030303
292937000000000000000000004444440036292937000000000000de00cf00382929390000030303030303030303030300000e0e000000dc00000e0e00000e0e00000e0e00000000003629293700dc00edee00000000000630000000200223202020200220022100000038292939000000dc0000001828282802020202020202
292937000000000000000004000000000036292937000000040000de00dfedee121300000302020202022202020202024444000000cd00dc000000000000000000000000060000000036292937000303030300000000000606000000000000000000000000000000000038292939000000dc0004002827280602202002022002
121300004800004444440014000006000000121300edee001400030303030303030303030202022002020202202302025252000000dd00dc000000edee70000000000000060070edee00121300030202020203030303030303007000edee00000000000000000000005200121300edee00dc0014002828300602022002240202
0303030303030303030303030303030303030303030303030303020202020202020202020222022320020220200202020303030303030303030303030303030303030303030303030303030303020222020202022002020202030303030303030303030303030303030303030303030303030303030303030302022320020202
2002020202210202020202020202220202020202020220200221020202022002200202230202020202020202200202020220020202020202022202020202020202220202020202020202020202200202200202020202230202020202220202022002020223020202020202022002220202022002022020200202020202202002
0223200220202002020220202102020202200202020202202002020202020202202002022120022102020202022420020202020202020202020202202002022002020220200220200202202020022002200202020202020202022302020202200202020202020202020202230202020202020202020202200202020220200202
0000000000000000000000000000000000000000000000000000000000001400140000000000000000140014000014000014140000140014000014000000001400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000001400140000000000000000140014000014000014140000140014000014000000001400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000001400140000000000000000000014000014000014140000140014000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000140000000000000000000014000014000014140000140014000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000014000014140000140014000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000014140000000014000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2739180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4828270017170400000000190000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000001a1a1a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010104000001010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0202020202200214050002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2002202002020214140002020200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010800002d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d07000000000000000000000000000000000000
010400000537005370053700537005370053700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000537005370053700000005370053700537000000
010400001c4501c4501c45000000000000000000000000001c4501c4501c45000000000000000000000000001c4501c4501c45000000000000000000000000001c4501c4501c4500000000000000000000000000
010400001555015550155500000000000000000000000000155501555015550000000000000000000000000015550155501555000000000000000000000000001555015550155500000000000000000000000000
010400002e0702e0702e0702e0702e0702e0702e0702e0702e0702e0702e0702e0702e07000000000000000030070300703007030070300703007030070300703007030070300703007030070000000000000000
010400000537005370053700537005370053700000000000053700537005370053700537005370000000000005370053700537005370053700537000000000000537005370053700537005370053700000000000
010400003207032070320703207032070320703207032070320703207032070320703207000000000000000030070300703007030070300703007030070300703007030070300703007030070000000000000000
010400001355013550135500000000000000000000000000135501355013550000000000000000000000000013550135501355000000000000000000000000001555015550155500000000000000000000000000
010400002e0702e0702e0702e0702e0702e0702e0702e0702e0702e0702e0702e0702e0700000000000000002d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d070000000000000000
010400002b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b07000000000000000000000000000000000000
010400000737007370073700737007370073700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000737007370073700000007370073700737000000
010400001d4501d4501d45000000000000000000000000001d4501d4501d45000000000000000000000000001d4501d4501d45000000000000000000000000001d4501d4501d4500000000000000000000000000
010400001655016550165500000000000000000000000000165501655016550000000000000000000000000016550165501655000000000000000000000000001655016550165500000000000000000000000000
010400002d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d07000000000000000029070290702907029070290702907029070290702907029070290702907029070000000000000000
010400000737007370073700737007370073700000000000073700737007370073700737007370000000000007370073700737007370073700737000000000000737007370073700737007370073700000000000
010400000c3700c3700c3700c3700c3700c3700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c3700c3700c370000000c3700c3700c37000000
010400001355013550135500000000000000000000000000135501355013550000000000000000000000000013550135501355000000000000000000000000001355013550135500000000000000000000000000
01040000240702407024070240702407024070240702407024070240702407024070240702407024070240702407024070240702407024070240702407024070240702b5002f7002450028700375003b70000000
010400002407024070240702407024070240702407024070240702407024070240702407024070240702407024070240702407024070240702407024070240702407000000000000000000000000000000000000
010400000c3700c3700c3700c3700c3700c37000000000000c3700c3700c3700c3700c3700c37000000000000c3700c3700c3700c3700c3700c37000000000000c3700c3700c3700c3700c3700c3700000000000
010400003707037070370703707037070370703707037070370703707037070370703707000000000000000035070350703507035070350703507035070350703507035070350703507035070000000000000000
010400003407034070340703407034070340703407034070340703407034070340703407000000000000000030070300703007030070300703007030070300703007030070300703007030070000000000000000
010400003507035070350703507035070350703507035070350703507035070350703507035070350703507035070350703507035070350703507035070350703507000000000000000000000000000000000000
010400003407034070340703407034070340703407034070340703407034070340703407000000000000000035070350703507035070350703507035070350703507035070350703507035070000000000000000
010400003207032070320703207032070320703207032070320703207032070320703207032070320703207032070320703207032070320703207032070320703207000000000000000000000000000000000000
010400003007030070300703007030070300703007030070300703007030070300703007000000000000000032070320703207032070320703207032070320703207032070320703207032070000000000000000
01040000300703007030070300703007030070300703007030070300703007030070300700000000000000002b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b070000000000000000
01040000320703207032070320703207032070320703207032070320703207032070320700000000000000002d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d0702d070000000000000000
01040000300703007030070300703007030070300703007030070300703007030070300700000000000000002b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b070000000000000000
010400001555015550155500000000000000000000000000155501555015550000000000000000000000000013550135501355000000000000000000000000001555015550155500000000000000000000000000
010400002b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b07000000000000000026070260702607026070260702607026070260702607026070260702607026070000000000000000
010400002907029070290702907029070290702907029070290702907029070290702907000000000000000024070240702407024070240702407024070240702407024070240702407024070000000000000000
010400002607026070260702607026070260702607026070260702607026070260702607000000000000000021070210702107021070210702107021070210702107021070210702107021070000000000000000
010400001155011550115500000000000000000000000000115501155011550000000000000000000000000011550115501155000000000000000000000000001355013550135500000000000000000000000000
01040000240702407024070240702407024070000000000026070260702607026070260702607000000000002b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b0702b070000000000000000
010400001355013550135500000000000000000000000000135501355013550000000000000000000000000011550115501155000000000000000000000000001355013550135500000000000000000000000000
010400002607026070260702607026070260700000000000210702107021070210702107021070000000000026070260702607026070260702607026070260702607026070260702607026070260702607026070
010400001155011550115500000000000000000000000000115501155011550000000000000000000000000011550115501155000000000000000000000000000000000000000000000000000000000000000000
010400002607026070260702607026070260702607026070260700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400002417024170241702417024170241700000000000261702617026170261702617026170000000000029170291702917029170291702917000000000002b1702b1702b1702b1702b1702b1700000000000
010400002817028170281702817028170281702817028170281702817028170281702817000000000000000024170241702417024170241702417024170241702417024170241702417024170000000000000000
010400003517035170351703517035170351703517035170351703517035170351703517000000000000000030170301703017030170301703017030170301703017030170301703017030170000000000000000
010400001155011550115500000000000000000000000000115501155011550000000000000000000000000011550115501155000000000000000000000000001555015550155500000000000000000000000000
0110000024500295002450024500295002b50000000000000000000000000000000020500225002450027500295002b5002e500295002950029500275002750027500255002050025500245001f5002450022500
011000002450022500245001f500000001f5001d500185000000020500000002250022500245002950024500295002b5002e5001d500295001f5002b5000000027500255002050025500295001f500295002b500
010400001350013500135000000000000000000000000000135001350013500000000000000000000000000013500135001350000000000000000000000000001550015500155000000000000000000000000000
010400002e0002e0002e0002e0002e0002e0002e0002e0002e0002e0002e0002e0002e0000000000000000002d0002d0002d0002d0002d0002d0002d0002d0002d0002d0002d0002d0002d000000000000000000
010400002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b0002b00000000000000000000000000000000000000
010400000730007300073000730007300073000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000730007300073000000007300073000730000000
01030000000000c540105301f540135301856016550135401353018560105501f54010530135601655013540135301a520105401f530105201a510135201f510165001d4001d4001d40000000000000000000000
01100000270752607724075200721f0751b0771a0751b075180721806218052180421803500000000000000016500165001650000000000000000000000000001650016500165000000000000000000000000000
010100001e0701f070220702a020340102d0002d0002d0002d0002d0002d0002d0002d00000000000000000029000290002900029000290002900029000290002900029000290002900029000000000000000000
010100002b7602e7503a73033740377302e75033730337303372035710377103a710337103a7103c7103c70007300073000730007300073000730000000000000730007300073000730007300073000000000000
010200002965021630136301e63012620126301322017630176300b6301361012110116100d1100a6100a61008610106000d60004600116000e60011600126000c3000c3000c300000000c3000c3000c30000000
010200002005325043160231002304013000000000000000135001350013500000000000000000000000000013500135001350000000000000000000000000001350013500135000000000000000000000000000
0102000013571165731b5751d5711157313575165711b5731b575225711b573185751b5711f573245751b5711f57324565295611f563185611d555245532b5552b5412b5433053137535335333a5212b5252e513
010200002b571275711b57118571105710b57106571045710457106561035510454103531015210153105531035210a5210f5200c5200f72016510167101d5101d510245102b5100050000500005000050000500
01020000281602a1502c14029440220301f030220301b0201d0201d020160200f02013020130100c010110100f5100a5100a5100c5100c51007510075100a5100501003010375003b7003050034700375003b700
010200001557015570165701657017560185401a5401c5301f5202251029510005000050000500005000050030000300003000030000300003000030000300003000030000300003000030000000000000000000
010200001c17023170201701317012170161600d0600c0500b0400b0400c0300a0200802007010060103500035000350003500035000350003500035000350003500000000000000000000000000000000000000
01080000185461c5361f526215161f54621536245262851624546285362b5262f5162b54630536345263751635000350003500035000350003500035000350003500035000350003500035000000000000000000
01020000125501455017550195501c550235502a55032000320003200032000320003200032000320003200032000320003200032000320003200032000320003200000000000000000000000000000000000000
0101000023570215701f5601d5501b540115400f5300d5100a1100c1100d1100f1101351000500005000050032000320003200032000320003200032000320003200032000320003200032000000000000000000
01010000320003200032000320003200032000320003200032000320003200032000320000000000000000002d0002d0002d0002d0002d0002d0002d0002d0002d0002d0002d0002d0002d000000000000000000
__music__
01 00010203
00 04050203
00 06010207
00 08050203
00 090a0b0c
00 0d0e0b0c
00 090f0b10
00 12130b10
00 00010203
00 04050203
00 14010207
00 15050203
00 160a0b0c
00 170e0b0c
00 180f0b10
00 19130b10
00 15010203
00 1b050203
00 1c010207
00 0d05021d
00 1e0f0b10
00 1f130b10
00 200f0b21
00 22130b23
00 15010203
00 1b050203
00 1c010207
00 0d050203
00 1e0f0b10
00 1f130b10
00 240f0b25
00 2627130b
00 00010203
00 04050203
00 06010207
00 08050203
00 090a0b0c
00 0d0e0b0c
00 090f0b10
00 12130b10
00 00010203
00 04050203
00 14010207
00 15050203
00 160a0b0c
00 170e0b0c
00 180f0b10
00 19130b10
00 15010203
00 1b050203
00 1c010207
00 0d05021d
00 1e0f0b10
00 28130b10
00 200f0b21
00 22130b23
00 29010203
00 1b050203
00 1c010207
00 0d050203
00 1e0f0b10
00 28130b10
00 240f0b2a
02 2627130b

