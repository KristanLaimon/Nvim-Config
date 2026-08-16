---@meta
-- LÖVE 2D Game Engine Global Types Definition
-- Injected dynamically by KRS Type Injector

---@class love.Object
---@field release fun(self: love.Object): boolean Destroys the object's Lua reference and frees C memory.
---@field type fun(self: love.Object): string Gets the type of the object as a string.
---@field typeOf fun(self: love.Object, name: string): boolean Checks whether an object is of a certain type.
---@field isDestroyed fun(self: love.Object): boolean Checks whether an object has been released.

---@class love.Drawable : love.Object

---@class love.Texture : love.Drawable
---@field getWidth fun(self: love.Texture): integer Gets the width of the Texture in pixels.
---@field getHeight fun(self: love.Texture): integer Gets the height of the Texture in pixels.
---@field getDimensions fun(self: love.Texture): integer, integer Gets width and height of the Texture.
---@field setFilter fun(self: love.Texture, min: 'linear'|'nearest', mag?: 'linear'|'nearest', anisotropy?: number): nil Sets scaling filter modes.
---@field getFilter fun(self: love.Texture): string, string, number Gets scaling filter modes.
---@field setWrap fun(self: love.Texture, horiz: 'clamp'|'repeat'|'mirroredrepeat', vert?: string): nil Sets texture wrapping mode.
---@field getWrap fun(self: love.Texture): string, string Gets texture wrapping mode.

---@class love.Image : love.Texture

---@class love.Canvas : love.Texture
---@field renderTo fun(self: love.Canvas, func: fun()): nil Render to the canvas using a function callback.
---@field newImageData fun(self: love.Canvas): love.ImageData Create ImageData from the Canvas contents.

---@class love.Font : love.Object
---@field getHeight fun(self: love.Font): integer Gets font height in pixels.
---@field getWidth fun(self: love.Font, text: string): integer Gets line width of formatted text.
---@field setFilter fun(self: love.Font, min: string, mag?: string): nil Sets font texture filter.
---@field getFilter fun(self: love.Font): string, string Gets font texture filter.
---@field setLineHeight fun(self: love.Font, height: number): nil Sets line height scaling factor.
---@field getLineHeight fun(self: love.Font): number Gets line height scaling factor.
---@field hasGlyphs fun(self: love.Font, ...: string|integer): boolean Checks if glyphs exist in font.

---@class love.Source : love.Object
---@field play fun(self: love.Source): boolean Starts audio playback.
---@field pause fun(self: love.Source): nil Pauses audio playback.
---@field stop fun(self: love.Source): nil Stops audio playback.
---@field setVolume fun(self: love.Source, volume: number): nil Sets audio volume (0.0 to 1.0).
---@field getVolume fun(self: love.Source): number Gets current audio volume.
---@field setLooping fun(self: love.Source, loop: boolean): nil Sets whether audio loops.
---@field isLooping fun(self: love.Source): boolean Returns true if audio is looping.
---@field clone fun(self: love.Source): love.Source Creates a twin copy of the Source.
---@field setPitch fun(self: love.Source, pitch: number): nil Sets playback pitch multiplier.
---@field getPitch fun(self: love.Source): number Gets playback pitch multiplier.
---@field isPlaying fun(self: love.Source): boolean Returns true if source is playing.

---@class love.Shader : love.Object
---@field send fun(self: love.Shader, name: string, ...: any): nil Sends uniform data to the shader.
---@field hasUniform fun(self: love.Shader, name: string): boolean Returns true if shader has uniform variable.

---@class love.Quad : love.Object
---@field setViewport fun(self: love.Quad, x: number, y: number, w: number, h: number, sw?: number, sh?: number): nil Sets texture coordinate rectangle.
---@field getViewport fun(self: love.Quad): number, number, number, number, number, number Gets texture coordinate rectangle.

---@class love.Data : love.Object
---@field getSize fun(self: love.Data): integer Size of data in bytes.
---@field getString fun(self: love.Data): string Get full data content as string.

---@class love.FileData : love.Data
---@class love.ImageData : love.Data
---@field getWidth fun(self: love.ImageData): integer Width of image data in pixels.
---@field getHeight fun(self: love.ImageData): integer Height of image data in pixels.
---@field getDimensions fun(self: love.ImageData): integer, integer Width and height of image data.
---@field getPixel fun(self: love.ImageData, x: integer, y: integer): number, number, number, number Get RGBA color of pixel.
---@field setPixel fun(self: love.ImageData, x: integer, y: integer, r: number, g: number, b: number, a: number): nil Set RGBA color of pixel.

---@class love.SoundData : love.Data
---@class love.Rasterizer : love.Object
---@class love.FontData : love.Object
---@class love.CompressedData : love.Data
---@class love.Decoder : love.Object

---@class love.World : love.Object
---@field update fun(self: love.World, dt: number): nil Advances physics simulation by time dt.
---@field setCallbacks fun(self: love.World, beginContact?: fun(), endContact?: fun(), preSolve?: fun(), postSolve?: fun()): nil Sets collision callbacks.
---@field getBodyCount fun(self: love.World): integer Get number of bodies in world.

---@class love.Body : love.Object
---@field getPosition fun(self: love.Body): number, number Get body position (x, y).
---@field setPosition fun(self: love.Body, x: number, y: number): nil Set body position (x, y).
---@field getLinearVelocity fun(self: love.Body): number, number Get linear velocity vector.
---@field setLinearVelocity fun(self: love.Body, x: number, y: number): nil Set linear velocity vector.
---@field applyForce fun(self: love.Body, fx: number, fy: number): nil Apply force vector to body.
---@field applyImpulse fun(self: love.Body, ix: number, iy: number): nil Apply impulse vector to body.
---@field destroy fun(self: love.Body): nil Destroy body and release physics resources.

---@class love.Fixture : love.Object
---@field setSensor fun(self: love.Fixture, sensor: boolean): nil Set fixture sensor mode.
---@field isSensor fun(self: love.Fixture): boolean Returns true if fixture is sensor.
---@field setUserData fun(self: love.Fixture, data: any): nil Attach custom Lua data to fixture.
---@field getUserData fun(self: love.Fixture): any Get attached custom Lua data.

---@class love.Shape : love.Object
---@class love.CircleShape : love.Shape
---@class love.PolygonShape : love.Shape

---@class love.Thread : love.Object
---@field start fun(self: love.Thread, ...: any): nil Start thread execution.
---@field wait fun(self: love.Thread): nil Wait for thread completion.
---@field isRunning fun(self: love.Thread): boolean Check if thread is executing.
---@field getError fun(self: love.Thread): string? Get thread error message if any.

---@class love.Channel : love.Object
---@field push fun(self: love.Channel, value: any): integer Push value to channel message queue.
---@field pop fun(self: love.Channel): any Pop message from channel queue.
---@field supply fun(self: love.Channel, value: any): boolean Send value blocking until retrieved.
---@field demand fun(self: love.Channel): any Retrieve message blocking until available.
---@field peek fun(self: love.Channel): any Inspect first message without popping.
---@field getCount fun(self: love.Channel): integer Get number of pending messages.
---@field clear fun(self: love.Channel): nil Clear channel queue.

---@class love.RandomGenerator : love.Object
---@field random fun(self: love.RandomGenerator, min?: number, max?: number): number Generate random float or integer.
---@field setSeed fun(self: love.RandomGenerator, seed: integer, low?: integer): nil Set random generator seed.

---@class love.BezierCurve : love.Object
---@field evaluate fun(self: love.BezierCurve, t: number): number, number Evaluate curve at position t (0.0 to 1.0).
---@field render fun(self: love.BezierCurve, depth?: integer): number[] Get rendered line coordinates.

---@class love.Cursor : love.Object
---@class love.Joystick : love.Object
---@field getName fun(self: love.Joystick): string Get joystick name.
---@field isDown fun(self: love.Joystick, ...: integer): boolean Check if joystick buttons are held.
---@field getAxis fun(self: love.Joystick, axis: integer): number Get joystick axis value (-1.0 to 1.0).
---@field isConnected fun(self: love.Joystick): boolean Check if joystick is connected.

---@class love.Video : love.Drawable
---@field play fun(self: love.Video): nil Play video stream.
---@field pause fun(self: love.Video): nil Pause video stream.
---@field rewind fun(self: love.Video): nil Rewind video to start.
---@field isPlaying fun(self: love.Video): boolean Check if video is playing.

---@class love.WindowFlags
---@field fullscreen? boolean
---@field fullscreentype? 'desktop'|'exclusive'
---@field vsync? integer
---@field msaa? integer
---@field resizable? boolean
---@field borderless? boolean
---@field centered? boolean
---@field display? integer
---@field minwidth? integer
---@field minheight? integer
---@field highdpi? boolean
---@field x? integer
---@field y? integer

---@class love.FileDataInfo
---@field size integer File size in bytes.
---@field modtime integer Modification timestamp in seconds.
---@field type 'file'|'directory'|'symlink'|'other' Path entry type.

---@class love.graphics
---@field draw fun(drawable: love.Drawable, x?: number, y?: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number): nil
---@field draw fun(texture: love.Texture, quad: love.Quad, x?: number, y?: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number): nil
---@field print fun(text: string|table, x?: number, y?: number, r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number): nil
---@field printf fun(text: string|table, x: number, y: number, limit: number, align?: 'left'|'center'|'right'|'justify', r?: number, sx?: number, sy?: number, ox?: number, oy?: number, kx?: number, ky?: number): nil
---@field rectangle fun(mode: 'fill'|'line', x: number, y: number, width: number, height: number, rx?: number, ry?: number): nil
---@field circle fun(mode: 'fill'|'line', x: number, y: number, radius: number, segments?: integer): nil
---@field line fun(...: number): nil
---@field polygon fun(mode: 'fill'|'line', ...: number): nil
---@field ellipse fun(mode: 'fill'|'line', x: number, y: number, rx: number, ry: number): nil
---@field arc fun(mode: 'fill'|'line', arctype: 'pie'|'open'|'closed', x: number, y: number, radius: number, angle1: number, angle2: number, segments?: integer): nil
---@field points fun(...: number): nil
---@field setColor fun(red: number, green: number, blue: number, alpha?: number): nil
---@field getColor fun(): number, number, number, number
---@field setBackgroundColor fun(red: number, green: number, blue: number, alpha?: number): nil
---@field getBackgroundColor fun(): number, number, number, number
---@field clear fun(r?: number, g?: number, b?: number, a?: number): nil
---@field present fun(): nil
---@field newImage fun(filename: string|love.FileData|love.ImageData): love.Image
---@field newFont fun(filename: string, size?: integer): love.Font
---@field newFont fun(size?: integer): love.Font
---@field newCanvas fun(width?: integer, height?: integer): love.Canvas
---@field newShader fun(code: string): love.Shader
---@field newQuad fun(x: number, y: number, width: number, height: number, sw: number, sh: number): love.Quad
---@field setCanvas fun(canvas?: love.Canvas|love.Canvas[]): nil
---@field getCanvas fun(): love.Canvas?
---@field setShader fun(shader?: love.Shader): nil
---@field getShader fun(): love.Shader?
---@field setFont fun(font: love.Font): nil
---@field getFont fun(): love.Font
---@field push fun(stack?: 'transform'|'all'): nil
---@field pop fun(): nil
---@field rotate fun(angle: number): nil
---@field scale fun(sx: number, sy?: number): nil
---@field translate fun(dx: number, dy: number): nil
---@field shear fun(kx: number, ky: number): nil
---@field origin fun(): nil
---@field getWidth fun(): integer
---@field getHeight fun(): integer
---@field getDimensions fun(): integer, integer
---@field setScissor fun(x?: number, y?: number, width?: number, height?: number): nil
---@field getScissor fun(): number, number, number, number
---@field setBlendMode fun(mode: 'alpha'|'add'|'subtract'|'multiply'|'replace'|'screen', alphamode?: 'alphamultiplied'|'premultiplied'): nil
---@field getBlendMode fun(): string, string
---@field setLineWidth fun(width: number): nil
---@field getLineWidth fun(): number
---@field setLineStyle fun(style: 'rough'|'smooth'): nil

---@class love.audio
---@field play fun(source: love.Source): nil
---@field pause fun(source?: love.Source): nil
---@field stop fun(source?: love.Source): nil
---@field setVolume fun(volume: number): nil
---@field getVolume fun(): number
---@field newSource fun(filename: string|love.FileData|love.SoundData, type: 'static'|'stream'): love.Source
---@field setPosition fun(x: number, y: number, z: number): nil
---@field getPosition fun(): number, number, number
---@field setVelocity fun(x: number, y: number, z: number): nil
---@field getVelocity fun(): number, number, number
---@field setOrientation fun(fx: number, fy: number, fz: number, ux: number, uy: number, uz: number): nil
---@field getActiveSourceCount fun(): integer

---@class love.event
---@field quit fun(exitstatus?: integer|'restart'): nil
---@field pump fun(): nil
---@field push fun(n: string, a?: any, b?: any, c?: any, d?: any, e?: any, f?: any): nil
---@field poll fun(): fun(): string, any, any, any, any, any, any
---@field wait fun(): string, any, any, any, any, any, any
---@field clear fun(): nil

---@class love.filesystem
---@field read fun(name: string, bytes?: integer): string?, integer?
---@field write fun(name: string, data: string|love.Data, size?: integer): boolean, string?
---@field append fun(name: string, data: string|love.Data, size?: integer): boolean, string?
---@field getInfo fun(path: string, filtertype?: string): love.FileDataInfo?
---@field getDirectoryItems fun(dir: string): string[]
---@field createDirectory fun(name: string): boolean
---@field remove fun(name: string): boolean
---@field lines fun(name: string): fun(): string
---@field load fun(name: string): fun(...: any): any, string?
---@field setIdentity fun(name: string): nil
---@field getIdentity fun(): string
---@field getSaveDirectory fun(): string
---@field getWorkingDirectory fun(): string
---@field getUserDirectory fun(): string
---@field newFileData fun(contents: string, name: string): love.FileData

---@class love.font
---@field newFontData fun(rasterizer: any): love.FontData
---@field newRasterizer fun(filename: string): love.Rasterizer

---@class love.image
---@field newImageData fun(width: integer, height: integer): love.ImageData
---@field newImageData fun(filename: string): love.ImageData
---@field newCompressedData fun(filename: string): love.CompressedData
---@field isCompressed fun(filename: string): boolean

---@class love.keyboard
---@field isDown fun(...: string): boolean
---@field setKeyRepeat fun(enable: boolean): nil
---@field hasKeyRepeat fun(): boolean
---@field hasTextInput fun(): boolean
---@field setTextInput fun(enable: boolean, x?: number, y?: number, w?: number, h?: number): nil
---@field getScancodeFromKey fun(key: string): string
---@field getKeyFromScancode fun(scancode: string): string

---@class love.math
---@field random fun(min?: number, max?: number): number
---@field setRandomSeed fun(seed: integer, low?: integer): nil
---@field getRandomSeed fun(): integer, integer
---@field noise fun(x: number, y?: number, z?: number, w?: number): number
---@field gammaToLinear fun(r: number, g: number, b: number): number, number, number
---@field linearToGamma fun(r: number, g: number, b: number): number, number, number
---@field newRandomGenerator fun(seed?: integer): love.RandomGenerator
---@field newBezierCurve fun(...: number): love.BezierCurve
---@field triangulate fun(polygon: number[]): number[][]

---@class love.mouse
---@field getPosition fun(): number, number
---@field getX fun(): number
---@field getY fun(): number
---@field setPosition fun(x: number, y: number): nil
---@field isDown fun(...: integer): boolean
---@field setVisible fun(visible: boolean): nil
---@field isVisible fun(): boolean
---@field setCursor fun(cursor?: love.Cursor): nil
---@field getCursor fun(): love.Cursor?
---@field newCursor fun(imageData: love.ImageData, hotx?: integer, hoty?: integer): love.Cursor
---@field setRelativeMode fun(enable: boolean): nil
---@field getRelativeMode fun(): boolean

---@class love.physics
---@field newWorld fun(gx?: number, gy?: number, sleep?: boolean): love.World
---@field newBody fun(world: love.World, x?: number, y?: number, type?: 'static'|'dynamic'|'kinematic'): love.Body
---@field newFixture fun(body: love.Body, shape: love.Shape, density?: number): love.Fixture
---@field newRectangleShape fun(width: number, height: number): love.PolygonShape
---@field newCircleShape fun(radius: number): love.CircleShape
---@field newPolygonShape fun(...: number): love.PolygonShape
---@field setMeter fun(scale: number): nil
---@field getMeter fun(): number

---@class love.sound
---@field newSoundData fun(filename: string): love.SoundData
---@field newDecoder fun(filename: string): love.Decoder

---@class love.system
---@field getOS fun(): 'OS X'|'Windows'|'Linux'|'Android'|'iOS'|string
---@field getProcessorCount fun(): integer
---@field getPowerInfo fun(): 'unknown'|'battery'|'nobattery'|'charging'|'charged', integer?, integer?
---@field getClipboardText fun(): string
---@field setClipboardText fun(text: string): nil
---@field openURL fun(url: string): boolean

---@class love.thread
---@field newThread fun(filename: string|love.FileData): love.Thread
---@field newChannel fun(): love.Channel
---@field getChannel fun(name: string): love.Channel

---@class love.timer
---@field step fun(): number
---@field getDelta fun(): number
---@field getFPS fun(): integer
---@field getTime fun(): number
---@field sleep fun(s: number): nil

---@class love.touch
---@field getTouches fun(): table[]
---@field getPosition fun(id: any): number, number
---@field getPressure fun(id: any): number

---@class love.video
---@field newVideo fun(filename: string): love.Video

---@class love.window
---@field setMode fun(width: integer, height: integer, flags?: love.WindowFlags): boolean
---@field getMode fun(): integer, integer, love.WindowFlags
---@field setTitle fun(title: string): nil
---@field getTitle fun(): string
---@field setIcon fun(imageData: love.ImageData): boolean
---@field setFullscreen fun(fullscreen: boolean, fstype?: 'desktop'|'exclusive'): boolean
---@field getFullscreen fun(): boolean, string
---@field isOpen fun(): boolean
---@field close fun(): nil
---@field getDesktopDimensions fun(display?: integer): integer, integer
---@field setVSync fun(vsync: integer): nil
---@field getVSync fun(): integer

---@class love.joystick
---@field getJoysticks fun(): love.Joystick[]
---@field getJoystickCount fun(): integer

---@class love.data
---@field compress fun(container: 'string'|'data', format: 'lz4'|'zlib'|'gzip', data: string|love.Data, level?: integer): any
---@field decompress fun(container: 'string'|'data', format: 'lz4'|'zlib'|'gzip', compressedData: string|love.Data): any
---@field encode fun(container: 'string'|'data', format: 'base64'|'hex', sourceString: string, linelength?: integer): any
---@field decode fun(container: 'string'|'data', format: 'base64'|'hex', sourceString: string): any
---@field hash fun(functionality: 'md5'|'sha1'|'sha256'|'sha512', data: string|love.Data): string

---@class love
---@field graphics love.graphics Graphics rendering module
---@field audio love.audio Audio playing and recording module
---@field event love.event Application event handling
---@field filesystem love.filesystem File system I/O module
---@field font love.font Font loading and rasterization module
---@field image love.image Image decoding and manipulation module
---@field keyboard love.keyboard Keyboard input module
---@field math love.math Math, random number and geometry helpers
---@field mouse love.mouse Mouse hardware input module
---@field physics love.physics 2D rigid body physics engine (Box2D)
---@field sound love.sound Sound decoding and raw audio buffer module
---@field system love.system System info and clipboard interaction
---@field thread love.thread Multi-threading module
---@field timer love.timer Delta time and FPS tracking module
---@field touch love.touch Touch screen gesture input module
---@field video love.video Video playback stream module
---@field window love.window Window management and OS display settings
---@field joystick love.joystick Gamepad and joystick input module
---@field data love.data Data hashing, encoding, compression module
---@field load? fun(arg: string[], unfilteredArg: string[]) Game initialization callback
---@field update? fun(dt: number) Game update step callback
---@field draw? fun() Render frame callback
---@field keypressed? fun(key: string, scancode: string, isrepeat: boolean) Key press callback
---@field keyreleased? fun(key: string, scancode: string) Key release callback
---@field mousepressed? fun(x: number, y: number, button: number, isTouch: boolean, presses: number) Mouse press callback
---@field mousereleased? fun(x: number, y: number, button: number, isTouch: boolean, presses: number) Mouse release callback
---@field mousemoved? fun(x: number, y: number, dx: number, dy: number, istouch: boolean) Mouse motion callback
---@field wheelmoved? fun(x: number, y: number) Mouse wheel scroll callback
---@field textinput? fun(text: string) Text input callback
---@field resize? fun(w: number, h: number) Window resize callback
---@field quit? fun(): boolean? Quit event callback
---@field run? fun(): function Main game loop constructor
---@field errorhandler? fun(msg: string): function? Error handler handler callback
love = love or {}
