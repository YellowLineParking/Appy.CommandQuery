using System;
using System.Threading;
using System.Threading.Tasks;
using Endjin.Core.Retry;
using Endjin.Core.Retry.Policies;
using Endjin.Core.Retry.Strategies;

namespace Appy.CommandQuery
{
    public class DataSource : IDataSource
    {
        readonly IRetryStrategy _retryStrategyStrategy;
        readonly IRetryPolicy _retryPolicy;
        readonly Func<Type, object> _getDataSource;

        public DataSource(Func<Type, object> getDataSource) =>
            _getDataSource = getDataSource;

        public DataSource(Func<Type, object> getDataSource, IRetryStrategy retryStrategy, IRetryPolicy retryPolicy) : this(getDataSource)
        {
            _retryStrategyStrategy = retryStrategy;
            _retryPolicy = retryPolicy;
        }

        T source<T>() =>
            (T) _getDataSource(typeof(T));

        public Task<TReturnType> Get<TReturnType, TDataSource>(IQuery<TReturnType, TDataSource> query) => 
            _retryStrategyStrategy == null 
                ? query.Get(source<TDataSource>()) 
            : Retriable.Retry(() => query.Get(source<TDataSource>()), CancellationToken.None, _retryStrategyStrategy, _retryPolicy);

        public Task<TReturnType> Execute<TReturnType, TDataSource>(ICommand<TReturnType, TDataSource> command) =>
            _retryStrategyStrategy == null
                ? command.Execute(source<TDataSource>())
                : Retriable.RetryAsync(() => command.Execute(source<TDataSource>()), CancellationToken.None, _retryStrategyStrategy, _retryPolicy);

        public Task Execute<TDataSource>(ICommand<TDataSource> command) =>
            _retryStrategyStrategy == null
                ? command.Execute(source<TDataSource>())
                : Retriable.RetryAsync(() => command.Execute(source<TDataSource>()), CancellationToken.None, _retryStrategyStrategy, _retryPolicy);
    }
}