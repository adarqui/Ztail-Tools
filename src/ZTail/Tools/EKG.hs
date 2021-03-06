{-# LANGUAGE OverloadedStrings #-}

module ZTail.Tools.EKG (
    EKG(..),
    getLineLoop,
    ekg'bootstrap,
    timed,
    getTime
) where

import Control.Monad
import Control.Concurrent
import Control.Exception
import Data.List
import Data.Time.Clock.POSIX (getPOSIXTime)
import System.Environment
import System.Posix.Daemonize
import qualified Data.Text as T
import qualified System.Metrics.Distribution as Distribution
import qualified System.Metrics.Counter as Counter
import qualified System.Metrics.Gauge as Gauge
import qualified System.Metrics.Label as Label
import qualified System.Remote.Monitoring as Monitoring
import qualified System.Remote.Monitoring.Statsd as Statsd

data EKG = EKG {
    _server :: Monitoring.Server,
    _logCounter :: Counter.Counter,
    _dequeueErrorCounter :: Counter.Counter,
    _logDistribution :: Distribution.Distribution,
    _lengthGauge :: Gauge.Gauge
}


getLineLoop = forever $ getLine >> putStrLn "Loop."


ekg'bootstrap port io = do
    daemonize $ do
        argv <- getArgs
        handle <- Monitoring.forkServer "0.0.0.0" port
        Statsd.forkStatsd Statsd.defaultStatsdOptions (Monitoring.serverMetricStore handle)
        logCounter <- Monitoring.getCounter "logCounter" handle
        dequeueErrorCounter <- Monitoring.getCounter "dequeueErrorCounter" handle
        logDistribution <- Monitoring.getDistribution "logDistribution" handle
        lengthGauge <- Monitoring.getGauge "lengthGauge" handle
        label <- Monitoring.getLabel "argv" handle
        Label.set label $ T.pack $ concat $ intersperse " " argv
        let ekg = EKG { _server = handle, _logCounter = logCounter, _logDistribution = logDistribution, _lengthGauge = lengthGauge, _dequeueErrorCounter = dequeueErrorCounter }
        io ekg


timed :: IO a -> IO Double
timed m = do
    start <- getTime
    m
    end <- getTime
    return $! end - start


getTime :: IO Double
getTime = realToFrac `fmap` getPOSIXTime
