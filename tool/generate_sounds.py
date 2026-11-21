import os
import wave
import math
import struct

def write_wav(filename, duration, sample_rate, wave_func):
    num_samples = int(duration * sample_rate)
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'wb') as w:
        w.setnchannels(1)  # Mono
        w.setsampwidth(2)  # 16-bit
        w.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = i / sample_rate
            val = wave_func(t, duration)
            val = max(-1.0, min(1.0, val))
            sample = int(val * 32767)
            data = struct.pack('<h', sample)
            w.writeframesraw(data)

def generate_light_click(t, duration):
    freq1 = 1500.0
    freq2 = 2800.0
    decay = math.exp(-t / 0.005)
    signal = 0.7 * math.sin(2.0 * math.pi * freq1 * t) + 0.3 * math.sin(2.0 * math.pi * freq2 * t)
    noise = math.sin(math.sin(t * 100000.0) * 10000.0)
    noise_envelope = math.exp(-t / 0.002)
    return (signal * decay) + 0.15 * noise * noise_envelope

def generate_bubble_pop(t, duration):
    f_start = 280.0
    f_end = 850.0
    freq = f_start + (f_end - f_start) * (t / duration)
    phase = 2.0 * math.pi * (f_start * t + ((f_end - f_start) / (2.0 * duration)) * t * t)
    attack_time = 0.005
    env = t / attack_time if t < attack_time else math.exp(-(t - attack_time) / 0.02)
    signal = math.sin(phase)
    phase_sub = 0.5 * phase
    sub_signal = math.sin(phase_sub)
    return (0.85 * signal + 0.15 * sub_signal) * env

def generate_brick_snap(t, duration):
    # Tactile 3D plastic brick snap: two micro-impacts + plastic body resonance
    decay1 = math.exp(-t / 0.004)
    click1 = (0.6 * math.sin(2.0 * math.pi * 2200.0 * t) + 
              0.4 * math.sin(2.0 * math.pi * 3800.0 * t)) * decay1
    
    # Second micro-click from stud locking in (offset by 5ms)
    t2 = t - 0.005
    click2 = 0.0
    if t2 > 0:
        decay2 = math.exp(-t2 / 0.004)
        click2 = 0.5 * math.sin(2.0 * math.pi * 2900.0 * t2) * decay2
        
    # Resonant hollow plastic block thud (320Hz)
    body_decay = math.exp(-t / 0.016)
    body = 0.35 * math.sin(2.0 * math.pi * 340.0 * t) * body_decay
    
    return click1 + click2 + body

def generate_bead_click(t, duration):
    # Hollow tubular plastic Perler bead sliding onto peg
    decay = math.exp(-t / 0.006)
    click = (0.5 * math.sin(2.0 * math.pi * 1850.0 * t) + 
             0.5 * math.sin(2.0 * math.pi * 4200.0 * t)) * decay
    # High plastic chime overtone
    overtone = 0.25 * math.sin(2.0 * math.pi * 6400.0 * t) * math.exp(-t / 0.003)
    return click + overtone

def generate_sticker_slap(t, duration):
    # Squishy vinyl peel-and-stick placement: fast pitch drop + vinyl tap
    f_start = 380.0
    f_end = 160.0
    phase = 2.0 * math.pi * (f_start * t + ((f_end - f_start) / (2.0 * duration)) * t * t)
    env = math.exp(-t / 0.018)
    slap = math.sin(phase) * env
    # Soft vinyl tap transient
    noise = math.sin(math.sin(t * 80000.0) * 8000.0) * math.exp(-t / 0.003) * 0.15
    return 0.85 * slap + noise

def generate_glow_pop(t, duration):
    # Luminous electric neon blip: warm upward sweep + crystal chime
    f_start = 320.0
    f_end = 940.0
    phase = 2.0 * math.pi * (f_start * t + ((f_end - f_start) / (2.0 * duration)) * t * t)
    env = math.exp(-t / 0.022)
    tone = math.sin(phase) * env
    shimmer = 0.2 * math.sin(2.0 * math.pi * 1880.0 * t) * math.exp(-t / 0.012)
    return 0.8 * tone + shimmer

def generate_mosaic_clink(t, duration):
    # Glazed ceramic porcelain clink: crisp high dual tone with fast crystalline decay
    decay = math.exp(-t / 0.005)
    tone = (0.6 * math.sin(2.0 * math.pi * 3100.0 * t) + 
            0.4 * math.sin(2.0 * math.pi * 5400.0 * t)) * decay
    ring = 0.25 * math.sin(2.0 * math.pi * 7800.0 * t) * math.exp(-t / 0.003)
    return tone + ring

def generate_fabric_soft(t, duration):
    # Soft woolen / linen cushion tap
    body = math.sin(2.0 * math.pi * 175.0 * t) * math.exp(-t / 0.020)
    # Subtle thread friction
    friction = math.sin(math.sin(t * 60000.0) * 4000.0) * math.exp(-t / 0.004) * 0.12
    return 0.88 * body + friction

def generate_number_clear(t, duration):
    # Triumphant golden ascending arpeggio chord (C5, E5, G5, C6)
    # 523.25 Hz, 659.25 Hz, 783.99 Hz, 1046.50 Hz
    notes = [
        (0.000, 523.25, 0.45),
        (0.035, 659.25, 0.50),
        (0.070, 783.99, 0.55),
        (0.105, 1046.50, 0.65),
    ]
    val = 0.0
    for start_t, freq, amp in notes:
        if t >= start_t:
            dt = t - start_t
            env = math.exp(-dt / 0.09)
            tone = (0.8 * math.sin(2.0 * math.pi * freq * dt) + 
                    0.2 * math.sin(2.0 * math.pi * (freq * 2) * dt))
            val += amp * tone * env
    return val

if __name__ == '__main__':
    sample_rate = 44100
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    audio_dir = os.path.join(base_dir, 'assets', 'audio')
    
    sounds = [
        ('light_click.wav', 0.05, generate_light_click),
        ('bubble_pop.wav', 0.08, generate_bubble_pop),
        ('brick_snap.wav', 0.06, generate_brick_snap),
        ('bead_click.wav', 0.05, generate_bead_click),
        ('sticker_slap.wav', 0.07, generate_sticker_slap),
        ('glow_pop.wav', 0.08, generate_glow_pop),
        ('mosaic_clink.wav', 0.06, generate_mosaic_clink),
        ('fabric_soft.wav', 0.06, generate_fabric_soft),
        ('number_clear.wav', 0.35, generate_number_clear),
    ]
    
    for filename, dur, func in sounds:
        path = os.path.join(audio_dir, filename)
        write_wav(path, duration=dur, sample_rate=sample_rate, wave_func=func)
        print(f"Generated {filename}")
