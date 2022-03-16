function sleep(ms) {
    return new Promise(resolve => timeoutID = setTimeout(resolve, ms))
}

const COLOR = Object.freeze({
    RESET: '\x1b[0m',
    FG_RED: '\x1b[31m',
    FG_GREEN: '\x1b[32m'
})

const useColor = (color, str) => `${color}${str}${COLOR.RESET}`;
const red = (str) => useColor(COLOR.FG_RED, str)
const green = (str) => useColor(COLOR.FG_GREEN, str)

let running = true;
let timeoutID = undefined;

process.on('SIGINT', () => {
    console.log(`${red('Stopping due to "Ctrl+C"')}`)
    running = false
    if (!!timeoutID) {
        clearTimeout(timeoutID)
    }
})

async function run() {
    while (running) {
        const envValue = process.env.MY_ENV
        const name = process.env.APP_NAME

        console.log(`${green(name)} is alive`)
        console.log(`env value is '${green(envValue)}'`)
        await sleep(5000)
    }
}

run()
