using System;
using System.Threading.Tasks;
using Polly;

namespace Appy.CommandQuery
{
    public class DataSource : IDataSource
    {
        readonly Policy _policy;
        readonly Func<Type, object> _getDataSource;

        public DataSource(Func<Type, object> getDataSource) =>
            _getDataSource = getDataSource;

        public DataSource(Func<Type, object> getDataSource, Policy policy) : this(getDataSource) => 
            _policy = policy;

        T source<T>() =>
            (T) _getDataSource(typeof(T));

        public Task<TReturnType> Get<TReturnType, TDataSource>(IQuery<TReturnType, TDataSource> query) => 
            _policy == null 
                ? query.Get(source<TDataSource>()) 
                : _policy.Execute(() => query.Get(source<TDataSource>()));

        public Task<TReturnType> Execute<TReturnType, TDataSource>(ICommand<TReturnType, TDataSource> command) =>
            _policy == null
                ? command.Execute(source<TDataSource>())
                : _policy.Execute(() => command.Execute(source<TDataSource>()));

        public Task Execute<TDataSource>(ICommand<TDataSource> command) =>
            _policy == null
                ? command.Execute(source<TDataSource>())
                : _policy.Execute(() => command.Execute(source<TDataSource>()));
    }
}