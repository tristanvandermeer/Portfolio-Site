const canvas = document.getElementById('bg');
const context = canvas.getContext('2d');
const wrap = document.getElementById('bg-wrap');

const colors = [ [17, 17, 17], [85, 85, 85], [170, 170, 170], [238, 238, 238] ];

canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

const bayer4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5]
].map(row => row.map(n => n / 16));

function waveField(nx, ny, time) {
    let v = 0;
    v += 0.25 * (0.5 + 0.5 * Math.cos(ny * 4.8 - time * 0.5));
    v += 0.3 * (0.5 + 0.5 * Math.cos(nx * 3.2 + time * 0.65));
    //v += 0.2 * (0.5 + 0.5 * Math.sin((nx + ny) * 7.5 + time * 0.9));
    
    v += 0.1 * (0.5 + 0.5 * Math.sin(Math.sqrt((nx-0.5)**2 + (ny-0.5)**2) * 11 - time * 1.1));
    return Math.max(0, Math.min(1, v)); // clamp
}   

const SCALE = 0.4; // render at lower res

let imageData = null;
let buf = null;

function resize() {
    canvas.width  = Math.floor(wrap.clientWidth * SCALE);
    canvas.height = Math.floor(wrap.clientHeight * SCALE);
    canvas.style.width  = wrap.clientWidth + 'px';
    canvas.style.height = wrap.clientHeight + 'px';
    imageData = context.createImageData(canvas.width, canvas.height);
    buf = new Uint32Array(imageData.data.buffer); // keep in sync
}

let speed = 0.0005;
let frameCount = 0


function render(timestamp) {
    frameCount++;

    const t = timestamp * speed;
    const W = canvas.width;
    const H = canvas.height;

    if (frameCount % 2 !== 0) {
        requestAnimationFrame(render);
        return;
    }

    for (let y = 0; y < H; y++) {
        const ny = y / (H - 1);
        const row = bayer4[y % 4];

        for (let x = 0; x < W; x++) {
            const nx = x / (W - 1);

            const brightness = waveField(nx, ny, t);

            const threshold = row[x % 4];
            const idx = brightness > threshold
                ? colors.length - 1
                : Math.floor(brightness * colors.length);

            const [r, g, b] = colors[Math.min(idx, colors.length - 1)];
            buf[y * W + x] = (255 << 24) | (b << 16) | (g << 8) | r;
        }   
        
    }

    context.putImageData(imageData, 0, 0);
    requestAnimationFrame(render);
}
requestAnimationFrame(render);  

window.addEventListener('resize', resize);
resize();