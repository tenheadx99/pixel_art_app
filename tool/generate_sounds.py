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
            # Clamp to prevent clipping
            val = max(-1.0, min(1.0, val))
            # Convert to 16-bit PCM integer
            sample = int(val * 32767)
            data = struct.pack('<h', sample)
            w.writeframesraw(data)

def generate_light_click(t, duration):
    # Quick, crisp keyboard/switch click
    # Dual frequency for a richer click sound
    freq1 = 1500.0
    freq2 = 2800.0
    
    # Rapid exponential decay (tau = 0.005 seconds)
    decay = math.exp(-t / 0.005)
    
    # Combination of frequencies
    signal = 0.7 * math.sin(2.0 * math.pi * freq1 * t) + 0.3 * math.sin(2.0 * math.pi * freq2 * t)
    
    # Add a tiny bit of white-noise burst at the very start for tactile feel
    # We can simulate noise using a fast pseudo-random sine wave
    noise = math.sin(math.sin(t * 100000.0) * 10000.0)
    noise_envelope = math.exp(-t / 0.002)
    
    return (signal * decay) + 0.15 * noise * noise_envelope

def generate_bubble_pop(t, duration):
    # Sweet, wet, resonant bubble pop sound
    # Sweeps upward quickly, then decays
    f_start = 280.0
    f_end = 850.0
    
    # Smooth upward sweep
    freq = f_start + (f_end - f_start) * (t / duration)
    phase = 2.0 * math.pi * (f_start * t + ((f_end - f_start) / (2.0 * duration)) * t * t)
    
    # Envelope with very fast attack and smooth exponential decay (tau = 0.015 seconds)
    attack_time = 0.005
    if t < attack_time:
        env = t / attack_time
    else:
        env = math.exp(-(t - attack_time) / 0.02)
        
    # Main tone
    signal = math.sin(phase)
    
    # Add a secondary lower harmonic for warmth/pop depth
    phase_sub = 0.5 * phase
    sub_signal = math.sin(phase_sub)
    
    combined = 0.85 * signal + 0.15 * sub_signal
    return combined * env

if __name__ == '__main__':
    # Sample rate 44.1 kHz
    sample_rate = 44100
    
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    audio_dir = os.path.join(base_dir, 'assets', 'audio')
    
    # Generate light click (0.05 seconds)
    click_path = os.path.join(audio_dir, 'light_click.wav')
    write_wav(click_path, duration=0.05, sample_rate=sample_rate, wave_func=generate_light_click)
    print(f"Generated light click at: {click_path}")
    
    # Generate bubble pop (0.08 seconds)
    pop_path = os.path.join(audio_dir, 'bubble_pop.wav')
    write_wav(pop_path, duration=0.08, sample_rate=sample_rate, wave_func=generate_bubble_pop)
    print(f"Generated bubble pop at: {pop_path}")
