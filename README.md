# Zevli

A simple, privacy-focused health dashboard for iPhone and Apple Watch, built with SwiftUI and HealthKit.

Zevli turns data from Apple Health into an easy-to-read daily overview — combining sleep, recovery, heart metrics and activity without overwhelming you with numbers.

On iPhone, Zevli provides a daily health dashboard, recovery insights and detailed sleep information. On Apple Watch, the same data is available at a glance through custom complications.

## Features

### iPhone

- **Daily Vibe** — a simple daily recovery score based on sleep, HRV and resting heart rate
- Daily overview of your key health metrics
- Sleep score with detailed sleep stages and interruptions
- HRV and resting heart rate tracking
- Heart rate, steps and active energy
- Daily check-in to compare how you feel with what your health data suggests
- Simple, contextual health insights
- Direct integration with Apple Health

### Apple Watch

- Apple Watch companion app
- Custom complications designed for quick, glanceable information
- Daily Vibe and recovery status
- Sleep Score
- Steps and heart rate
- Activity rings for Move, Exercise and Stand
- Multiple complication layouts for different watch faces

## Daily Vibe

Daily Vibe is Zevli's way of turning several recovery signals into one simple score.

The score combines:

- Sleep
- Heart rate variability (HRV)
- Resting heart rate

Rather than treating one measurement as the full picture, Zevli brings these signals together to provide a quick indication of how recovered you may be that day.

You can also check in with how you actually feel, because numbers are only half the story.

## Sleep Insights

Zevli provides a dedicated view for understanding your previous night's sleep.

Alongside total sleep duration, you can see:

- Sleep Score
- Fell asleep and wake-up times
- REM sleep
- Core sleep
- Deep sleep
- Time awake
- Overnight interruptions

The sleep score focuses on sleep duration and interruptions to provide a simple overview without trying to turn every sleep metric into a target.

## Health & Privacy

Zevli uses HealthKit to read health and activity information stored in Apple Health.

Currently supported metrics include:

- Sleep duration and sleep stages
- Sleep interruptions
- Heart rate variability (HRV)
- Resting heart rate
- Heart rate
- Steps
- Active energy
- Exercise minutes
- Stand hours

Health data is accessed through Apple's HealthKit APIs and is used to generate the information displayed within Zevli.

Zevli does not require you to create an account or manually enter your health data.

## Built With

- Swift
- SwiftUI
- HealthKit
- WidgetKit
- App Intents
- iOS
- watchOS

## Project Status

Zevli is currently a personal project and is under active development.

It started as an experiment with Apple Health data and custom Apple Watch complications, and has gradually grown into a complete health dashboard across iPhone and Apple Watch.

There is still plenty I want to explore and improve, particularly around longer-term insights, recovery scoring and making health data easier to understand without adding unnecessary complexity.

## Zevli on iPhone

### Daily health, at a glance

Your sleep, recovery, heart metrics and activity in one simple daily view.

<img src="https://github.com/user-attachments/assets/44e5af27-17f0-4af5-8ddc-9976328e75bc" width="750" alt="Zevli iPhone dashboard" />

### A closer look at your sleep

Sleep score, duration, stages and overnight insights.

<img src="https://github.com/user-attachments/assets/e400906b-ee29-4e77-a395-f03925bd3e15" width="350" alt="Zevli sleep insights" />

## Zevli on Apple Watch

### Your health, right on your wrist

Daily Vibe, activity, sleep and health metrics through glanceable complications.

<img src="https://github.com/user-attachments/assets/f369fd43-ca8e-4ec7-822d-d6e052e0b7a0" width="750" alt="Zevli Apple Watch" />


## Disclaimer

Zevli is intended for personal wellness and informational purposes only. It is not a medical device and should not be used for medical diagnosis or treatment.
